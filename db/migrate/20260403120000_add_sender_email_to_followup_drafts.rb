# frozen_string_literal: true

class AddSenderEmailToFollowupDrafts < ActiveRecord::Migration[8.0]
  def change
    add_column :followup_drafts, :sender_email, :string
  end
end
