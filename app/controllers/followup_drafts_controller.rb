# frozen_string_literal: true

class FollowupDraftsController < ApplicationController
  include ProjectScoped

  before_action :set_project, only: %i[index generate_for_project generate_for_meeting confirm_all dismiss_all]
  before_action :set_meeting_when_nested, only: %i[index generate_for_meeting confirm_all dismiss_all]
  before_action :require_meeting!, only: %i[generate_for_meeting]
  before_action :set_followup_draft_for_shallow, only: %i[update]

  def index
    if @meeting
      @drafts = drafts_scope_for_meeting(@meeting)
      @scope = :meeting
    else
      @drafts = drafts_scope_for_project(@project)
      @scope = :project
    end
    hydrate_missing_assignee_emails!(@drafts)
    @recently_sent_drafts = recently_sent_drafts
    @drafts_by_assignee = @drafts.group_by(&:assignee_name)
  end

  def generate_for_project
    unless project_open_action_items?
      redirect_back_or_to project_path(@project), alert: t("followup.generation.no_open_items"), status: :see_other
      return
    end

    enqueue_followup_generation_job(project_id: @project.id)
    redirect_back_or_to project_path(@project), notice: t("followup.generation.enqueued"), status: :see_other
  end

  def generate_for_meeting
    unless meeting_open_action_items?
      redirect_back_or_to project_meeting_path(@project, @meeting), alert: t("followup.generation.no_open_items"), status: :see_other
      return
    end

    enqueue_followup_generation_job(meeting_id: @meeting.id)
    redirect_back_or_to project_meeting_path(@project, @meeting), notice: t("followup.generation.enqueued"), status: :see_other
  end

  def update
    unless @draft.pending_review? || @draft.failed?
      redirect_back_or_to followup_review_path, alert: t("followup.review.send_not_allowed"), status: :see_other
      return
    end

    @draft.assign_attributes(followup_draft_fields_params)
    @draft.sender_email = current_user.email
    unless @draft.sendable?
      redirect_back_or_to followup_review_path, alert: t("followup.review.send_incomplete"), status: :see_other
      return
    end

    prior_status = @draft.status
    @draft.status = :confirmed
    if @draft.save
      @draft.log_event(:confirmed, actor: followup_actor) if prior_status != "confirmed"
      enqueue_send_if_applicable(@draft)
      redirect_back_or_to followup_review_path, notice: t("followup.review.send_queued"), status: :see_other
    else
      redirect_back_or_to followup_review_path, alert: @draft.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def confirm_all
    pending = pending_review_drafts_for_bulk.to_a
    queued = 0
    pending.each do |draft|
      next unless draft.sendable?

      draft.update!(status: :confirmed, sender_email: current_user.email)
      draft.log_event(:confirmed, actor: followup_actor)
      enqueue_send_if_applicable(draft)
      queued += 1
    end

    if queued.zero? && pending.any?
      redirect_back_or_to followup_review_path,
        alert: t("followup.review.confirm_all_incomplete"),
        status: :see_other
    else
      redirect_back_or_to followup_review_path,
        notice: t("followup.review.confirm_all_queued", count: queued),
        status: :see_other
    end
  end

  def dismiss_all
    pending_review_drafts_for_bulk.find_each do |draft|
      draft.update!(status: :dismissed)
      draft.log_event(:dismissed, actor: followup_actor)
    end
    redirect_back_or_to followup_review_path,
      notice: t("followup.review.dismiss_all_done"),
      status: :see_other
  end

  private
    def set_meeting_when_nested
      return if params[:meeting_id].blank?

      @meeting = @project.meetings.find(params[:meeting_id])
    end

    def require_meeting!
      return if @meeting

      redirect_to root_path, alert: t("followup.review.meeting_missing"), status: :see_other
    end

    def set_followup_draft_for_shallow
      @draft = FollowupDraft.find(params[:id])
      @project = current_user.projects.find(@draft.meeting.project_id)
      @meeting = @draft.meeting
    end

    def drafts_scope_for_meeting(meeting)
      meeting.followup_drafts
        .for_review_index
        .includes(:extracted_item)
        .order(:assignee_name, :created_at)
    end

    def drafts_scope_for_project(project)
      FollowupDraft.joins(:meeting)
        .where(meetings: { project_id: project.id })
        .merge(FollowupDraft.for_review_index)
        .includes(:extracted_item, :meeting)
        .order(:assignee_name, :created_at)
    end

    def recently_sent_drafts
      if @meeting
        @meeting.followup_drafts.sent.includes(:extracted_item).order(sent_at: :desc).limit(25)
      else
        FollowupDraft.joins(:meeting)
          .where(meetings: { project_id: @project.id })
          .sent
          .includes(:extracted_item, :meeting)
          .order(sent_at: :desc)
          .limit(40)
      end
    end

    def project_open_action_items?
      ExtractedItem.action_items.open.joins(:meeting).exists?(meetings: { project_id: @project.id })
    end

    def meeting_open_action_items?
      @meeting.extracted_items.action_items.open.exists?
    end

    def enqueue_followup_generation_job(meeting_id: nil, project_id: nil)
      job_args = {}
      job_args[:meeting_id] = meeting_id if meeting_id.present?
      job_args[:project_id] = project_id if project_id.present?
      if params.key?(:assignee_normalized)
        job_args[:assignee_normalized] =
          params.permit(:assignee_normalized)[:assignee_normalized].to_s.downcase.strip
      end
      FollowupGenerationJob.perform_later(**job_args)
    end

    def followup_draft_fields_params
      params.expect(followup_draft: [ :subject, :body, :assignee_email ])
    end

    def followup_actor
      current_user&.email.to_s.presence || "user"
    end

    def followup_review_path
      @meeting ? project_meeting_followup_drafts_path(@project, @meeting) : project_followup_drafts_path(@project)
    end

    def pending_review_drafts_for_bulk
      if @meeting
        @meeting.followup_drafts.pending_review
      else
        FollowupDraft.joins(:meeting).where(meetings: { project_id: @project.id }).pending_review
      end
    end

    def enqueue_send_if_applicable(draft)
      return unless draft.email? && draft.assignee_email.present?

      FollowupSendJob.perform_later(draft.id)
    end

    # Keep old pending drafts aligned with the latest Email Book mappings.
    def hydrate_missing_assignee_emails!(drafts)
      drafts.each do |draft|
        next unless draft.assignee_email.blank?
        next unless draft.pending_review? || draft.failed?

        resolution = Followup::AssigneeEmailResolver.call(
          project: @project,
          assignee_display_name: draft.assignee_name
        )

        attrs = { email_resolution_status: resolution.status.to_s }
        attrs[:assignee_email] = resolution.email if resolution.email.present?
        draft.update_columns(attrs.merge(updated_at: Time.current))
        draft.assign_attributes(attrs)
      end
    end
end
