# frozen_string_literal: true

class ProjectAssigneeContactsController < ApplicationController
  include ProjectScoped

  before_action :set_project
  before_action :set_contact, only: %i[update destroy]

  def index
    @contacts = @project.project_assignee_contacts.order(:assignee_name_normalized)
    @contact = @project.project_assignee_contacts.build
  end

  def create
    attrs, aliases_text = contact_attributes_from_params
    @contact = @project.project_assignee_contacts.build(attrs)
    @contact.aliases_text = aliases_text
    if @contact.save
      redirect_to project_project_assignee_contacts_path(@project), notice: t("followup.email_book.created"), status: :see_other
    else
      @contacts = @project.project_assignee_contacts.order(:assignee_name_normalized)
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
end
