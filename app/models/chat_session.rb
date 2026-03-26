class ChatSession < ApplicationRecord
  belongs_to :project
  belongs_to :meeting, optional: true
  has_many :chat_messages, dependent: :destroy

  validates :project, presence: true

  def cross_meeting?
    meeting_id.blank?
  end
end
