# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Project assignee contacts", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in_as(user) }

  describe "GET /projects/:project_id/project_assignee_contacts" do
    it "renders the email book" do
      get project_project_assignee_contacts_path(project)
      expect(response).to have_http_status(:ok)
    end

    it "lists unique speakers across uploaded project meetings" do
      meeting_one = create(:meeting, project: project)
      meeting_two = create(:meeting, project: project)
      create(
        :transcript,
        meeting: meeting_one,
        parsed_segments: [
          { "speaker" => "Alice", "text" => "First update." },
          { "speaker" => "Bob", "text" => "Second update." }
        ]
      )
      create(
        :transcript,
        meeting: meeting_two,
        parsed_segments: [
          { "speaker" => "Alice", "text" => "Another update." },
          { "speaker" => "Carol", "text" => "Wrap up." }
        ]
      )

      get project_project_assignee_contacts_path(project)

      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
      expect(response.body).to include("Carol")
    end
  end

  describe "POST /projects/:project_id/project_assignee_contacts" do
    it "creates a contact" do
      expect do
        post project_project_assignee_contacts_path(project), params: {
          project_assignee_contact: {
            assignee_name_normalized: "alice",
            default_email: "alice@example.com",
            aliases_text: "a. smith, Alice"
          }
        }
      end.to change { project.project_assignee_contacts.count }.by(1)

      contact = project.project_assignee_contacts.last
      expect(contact.assignee_name_normalized).to eq("alice")
      expect(contact.aliases).to include("a. smith", "Alice")
      expect(response).to redirect_to(project_project_assignee_contacts_path(project))
    end
  end

  describe "PATCH /projects/:project_id/project_assignee_contacts/:id" do
    it "updates a contact" do
      contact = create(:project_assignee_contact, project: project, default_email: "old@example.com")

      patch project_project_assignee_contact_path(project, contact), params: {
        project_assignee_contact: {
          assignee_name_normalized: contact.assignee_name_normalized,
          default_email: "new@example.com",
          aliases_text: ""
        }
      }

      expect(contact.reload.default_email).to eq("new@example.com")
      expect(response).to redirect_to(project_project_assignee_contacts_path(project))
    end
  end

  describe "DELETE /projects/:project_id/project_assignee_contacts/:id" do
    it "removes a contact" do
      contact = create(:project_assignee_contact, project: project)

      expect do
        delete project_project_assignee_contact_path(project, contact)
      end.to change { project.project_assignee_contacts.count }.by(-1)

      expect(response).to redirect_to(project_project_assignee_contacts_path(project))
    end
  end
end
