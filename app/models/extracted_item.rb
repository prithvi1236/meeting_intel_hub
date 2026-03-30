class ExtractedItem < ApplicationRecord
  belongs_to :meeting
  belongs_to :transcript_chunk, optional: true

  enum :item_type, { decision: "decision", action_item: "action_item" }
  enum :status, { open: "open", completed: "completed", dismissed: "dismissed" }

  validates :description, presence: true

  scope :decisions, -> { where(item_type: :decision) }
  scope :action_items, -> { where(item_type: :action_item) }
  scope :open, -> { where(status: :open) }

  after_commit :refresh_project_action_items_count

  private
    def refresh_project_action_items_count
      pr = meeting&.project
      return unless pr
      # Project may already be destroyed in the same cascade (e.g. deleting a project);
      # after_commit still runs but update_column would raise on a destroyed instance.
      return if pr.destroyed?

      count = ExtractedItem.action_items.joins(:meeting).where(meetings: { project_id: pr.id }).count
      pr.update_column(:total_action_items_count, count)
    end
end
