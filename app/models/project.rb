class Project < ApplicationRecord
  belongs_to :user
  has_many :meetings, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy
  has_many :speakers, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug

  scope :ordered, -> { order(updated_at: :desc) }

  def last_meeting_date
    meetings.maximum(:meeting_date)
  end

  private
    def assign_slug
      return if slug.present?

      base = name.to_s.parameterize
      return if base.blank?

      candidate = base
      n = 2
      while Project.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{n}"
        n += 1
      end
      self.slug = candidate
    end
end
