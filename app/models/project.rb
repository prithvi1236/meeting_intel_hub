class Project < ApplicationRecord
  belongs_to :user
  has_many :meetings, dependent: :destroy
  has_many :followup_drafts, through: :meetings
  has_many :project_assignee_contacts, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy
  has_many :speakers, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug
  before_destroy :purge_transcript_file_attachments

  scope :ordered, -> { order(updated_at: :desc) }

  def last_meeting_date
    meetings.maximum(:meeting_date)
  end

  private
    # Strip ActiveStorage rows before cascade destroy so purging never runs on a nil Transcript
    # (e.g. legacy record_id type mismatch). Orphan Transcript attachments are removed too.
    def purge_transcript_file_attachments
      transcript_ids = Transcript.where(meeting_id: meeting_ids).pluck(:id)
      if transcript_ids.any?
        downcased_ids = transcript_ids.map { |id| id.to_s.downcase }
        ActiveStorage::Attachment.where(record_type: "Transcript").where(
          "LOWER(TRIM(active_storage_attachments.record_id)) IN (?)",
          downcased_ids
        ).find_each { |attachment| purge_attachment_safe(attachment) }
      end

      ActiveStorage::Attachment.where(record_type: "Transcript").where(
        <<~SQL.squish
          NOT EXISTS (
            SELECT 1 FROM transcripts t
            WHERE LOWER(TRIM(t.id::text)) = LOWER(TRIM(active_storage_attachments.record_id))
          )
        SQL
      ).find_each { |attachment| purge_attachment_safe(attachment) }
    end

    def purge_attachment_safe(attachment)
      attachment.purge
    rescue StandardError => e
      Rails.logger.warn(
        "[Project#purge_attachment_safe] purge failed, deleting rows: #{e.class}: #{e.message}"
      )
      aid = attachment.id
      bid = attachment.blob_id
      ActiveStorage::Attachment.where(id: aid).delete_all
      ActiveStorage::Blob.where(id: bid).delete_all if bid.present?
    end

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
