# frozen_string_literal: true

class CreateProjectAssigneeContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :project_assignee_contacts, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid, index: true
      t.string :assignee_name_normalized, null: false
      t.string :default_email, null: false
      t.jsonb :aliases, null: false, default: []

      t.timestamps
    end

    add_index :project_assignee_contacts, [ :project_id, :assignee_name_normalized ], unique: true
    add_index :project_assignee_contacts, :assignee_name_normalized
  end
end
