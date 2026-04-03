# frozen_string_literal: true

module Followup
  class DraftGeneratorService
    Result = Struct.new(:drafts_created, :errors, keyword_init: true)

    def initialize(meeting: nil, project: nil, assignee_normalized: nil, ai_caller: nil)
      @meeting = meeting
      @project = project
      # nil => all assignees; a string (including "") filters to that normalized owner key only.
      @assignee_filter = assignee_normalized.nil? ? nil : assignee_normalized.to_s.downcase.strip
      @ai_caller = ai_caller || method(:default_ai_call)
      raise ArgumentError, "Provide exactly one of meeting: or project:" if (@meeting && @project) || (!@meeting && !@project)
    end

    def call
      groups = grouped_eligible_items
      planned = []

      groups.each do |(assignee_key, _meeting_id), items|
        next if !@assignee_filter.nil? && assignee_key != @assignee_filter

        item = items.first
        meeting = item.meeting
        project = meeting.project
        display_name = display_assignee_name(item)
        resolution = AssigneeEmailResolver.call(project: project, assignee_display_name: display_name)

        user_content = PromptBuilder.followup_user_message(
          meeting: meeting,
          assignee_display_name: display_name,
          items: items
        )

        parsed, parse_err = fetch_parsed_followup(user_content)
        return Result.new(drafts_created: [], errors: [ parse_err ].compact) if parse_err

        subject = parsed["subject"].to_s.strip
        body = parsed["body"].to_s.strip
        if subject.blank? || body.blank?
          return Result.new(drafts_created: [], errors: [ "AI returned empty subject or body for assignee #{display_name.inspect}" ])
        end

        planned << {
          items: items,
          resolution: resolution,
          subject: subject,
          body: body
        }
      end

      drafts_created = []
      ActiveRecord::Base.transaction do
        channel = FollowupConfig::DEFAULT_CHANNEL
        model_version = GroqService::CHAT_MODEL

        planned.each do |payload|
          payload[:items].each do |item|
            display_name = display_assignee_name(item)
            resolution = payload[:resolution]

            draft = FollowupDraft.create!(
              meeting: item.meeting,
              extracted_item: item,
              assignee_name: item.owner.presence || display_name,
              assignee_email: resolution.email,
              channel: channel,
              subject: payload[:subject],
              body: payload[:body],
              status: :pending_review,
              email_resolution_status: resolution.status.to_s,
              ai_model_version: model_version
            )
            drafts_created << draft
          end
        end
      end

      Result.new(drafts_created: drafts_created, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(drafts_created: [], errors: [ e.message ])
    rescue StandardError => e
      Result.new(drafts_created: [], errors: [ e.message ])
    end

    private
      def default_ai_call(model:, messages:, max_tokens:, temperature:)
        GroqService.followup_chat_completion(
          model: model,
          messages: messages,
          max_tokens: max_tokens,
          temperature: temperature
        )
      end

      def base_items_scope
        scope = ExtractedItem.action_items.open.includes(:meeting, meeting: :project).where.missing(:followup_draft)
        if @meeting
          scope.where(meeting_id: @meeting.id)
        else
          scope.joins(:meeting).where(meetings: { project_id: @project.id })
        end
      end

      def grouped_eligible_items
        items = base_items_scope.to_a
        items.group_by { |i| [ normalize_assignee_key(i.owner), i.meeting_id ] }
      end

      def normalize_assignee_key(owner)
        owner.to_s.downcase.strip
      end

      def display_assignee_name(item)
        item.owner.presence || I18n.t("followup.unassigned_assignee")
      end

      def fetch_parsed_followup(user_content)
        model = GroqService::CHAT_MODEL
        max_tokens = FollowupConfig::AI_MAX_TOKENS

        raw = @ai_caller.call(
          model: model,
          messages: [ { role: "user", content: user_content } ],
          max_tokens: max_tokens,
          temperature: 0.25
        )
        parsed, err = parse_followup_payload(raw)
        if err == :retry_parse
          raw2 = @ai_caller.call(
            model: model,
            messages: [ { role: "user", content: "#{user_content}\n\n#{PromptBuilder.json_retry_addendum}" } ],
            max_tokens: max_tokens,
            temperature: 0.1
          )
          parsed, err = parse_followup_payload(raw2)
          err = "AI JSON parse failed after retry" if err == :retry_parse
        end

        [ parsed, err ]
      rescue GroqService::Error => e
        [ nil, e.message ]
      end

      def parse_followup_payload(raw)
        json_text = ExtractedItems.extract_json_object(raw.to_s)
        data = JSON.parse(json_text)
        return [ data, nil ] if data.is_a?(Hash) && data["subject"] && data["body"]

        [ nil, "Invalid JSON shape from AI" ]
      rescue JSON::ParserError
        [ nil, :retry_parse ]
      rescue ExtractedItems::Error
        [ nil, :retry_parse ]
      end
  end
end
