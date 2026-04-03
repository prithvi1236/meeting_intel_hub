# frozen_string_literal: true

class ProjectAssigneeContactsController < ApplicationController
  include ProjectScoped

  before_action :set_project
  before_action :set_contact, only: %i[update destroy]

  def index
    @contacts = @project.project_assignee_contacts.order(:assignee_name_normalized)
    @contact = @project.project_assignee_contacts.build
    @speaker_contact_rows = speaker_contact_rows
  end

  def create
    attrs, aliases_text = contact_attributes_from_params
    @contact = @project.project_assignee_contacts.build(attrs)
    @contact.aliases_text = aliases_text
    if @contact.save
      redirect_to project_project_assignee_contacts_path(@project), notice: t("followup.email_book.created"), status: :see_other
    else
      @contacts = @project.project_assignee_contacts.order(:assignee_name_normalized)
      @speaker_contact_rows = speaker_contact_rows
      render :index, status: :unprocessable_content
    end
  end

  def update
    attrs, aliases_text = contact_attributes_from_params
    @contact.aliases_text = aliases_text
    if @contact.update(attrs)
      redirect_to project_project_assignee_contacts_path(@project), notice: t("followup.email_book.updated"), status: :see_other
    else
      @contacts = @project.project_assignee_contacts.order(:assignee_name_normalized)
      @speaker_contact_rows = speaker_contact_rows
      @editing_id = @contact.id
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @contact.destroy!
    redirect_to project_project_assignee_contacts_path(@project), notice: t("followup.email_book.removed"), status: :see_other
  end

  private
    def set_contact
      @contact = @project.project_assignee_contacts.find(params[:id])
    end

    def contact_attributes_from_params
      raw = params.expect(
        project_assignee_contact: [ :assignee_name_normalized, :default_email, :aliases_text ]
      )
      text = raw[:aliases_text].to_s
      aliases =
        if text.present?
          text.split(/[,\n]/).map(&:strip).reject(&:blank?).uniq
        else
          []
        end
      [
        {
          assignee_name_normalized: raw[:assignee_name_normalized],
          default_email: raw[:default_email],
          aliases: aliases
        },
        text
      ]
    end

    def speaker_contact_rows
      contacts_by_key = @contacts.index_by(&:assignee_name_normalized)
      speaker_names_for_email_book.map do |speaker_name|
        key = speaker_name.downcase
        {
          speaker_name: speaker_name,
          contact: contacts_by_key[key] || @project.project_assignee_contacts.build(
            assignee_name_normalized: key,
            aliases_text: speaker_name
          )
        }
      end
    end

    def speaker_names_for_email_book
      from_segments = @project.meetings.includes(:transcript).flat_map do |meeting|
        Array(meeting.transcript&.parsed_segments).filter_map do |segment|
          next unless segment.is_a?(Hash)

          speaker_name = segment.with_indifferent_access[:speaker].to_s.strip
          next if speaker_name.blank? || speaker_name.casecmp("Speaker").zero?

          speaker_name
        end
      end
      from_project = @project.speakers.pluck(:name).map { |name| name.to_s.strip }.reject(&:blank?)
      (from_segments + from_project).uniq.sort_by(&:downcase)
    end
end
