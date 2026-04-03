# frozen_string_literal: true

class CreateFollowupDraftsAndEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :followup_drafts, id: :uuid do |t|
      t.references :meeting, null: false, foreign_key: true, type: :uuid, index: true
      t.references :extracted_item, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :assignee_name, null: false
      t.string :assignee_email
      t.string :channel, null: false, default: "email"
      t.string :subject
      t.text :body, null: false
      t.string :status, null: false, default: "pending_review"
      t.string :email_resolution_status, null: false, default: "missing_email"
      t.datetime :scheduled_send_at
      t.datetime :sent_at
      t.text :delivery_error
      t.string :ai_model_version

      t.timestamps
    end

    add_index :followup_drafts, :status
    add_index :followup_drafts, :email_resolution_status
    add_index :followup_drafts, [ :meeting_id, :status ]
    add_index :followup_drafts, [ :meeting_id, :assignee_name ]

    create_table :followup_events, id: :uuid do |t|
      t.references :followup_draft, null: false, foreign_key: true, type: :uuid, index: true
      t.string :event_type, null: false
      t.string :actor, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :followup_events, :event_type
    add_index :followup_events, [ :followup_draft_id, :created_at ]
  end
end
