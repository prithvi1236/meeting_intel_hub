# frozen_string_literal: true

module Meetings
  # Creates one Meeting + Transcript per row; all-or-nothing transaction; enqueues jobs after commit.
  class BulkCreateFromUploads
    Result = Struct.new(:success, :meetings, :error, keyword_init: true)

    class << self
      # @param project [Project]
      # @param rows [Array<Hash>] :file (UploadedFile), :title (String), :meeting_date (optional String/Date)
      # @return [Result]
      def call(project:, rows:)
        rows = Array(rows)
        return Result.new(success: false, meetings: [], error: "No files to import.") if rows.empty?

        transcript_ids = []
        meetings = []
        error = nil

        ActiveRecord::Base.transaction do
          rows.each_with_index do |row, index|
            file = row[:file]
            errs = TranscriptUploadValidator.validate(
              file,
              allowed_extensions: TranscriptUploadValidator::MODAL_ALLOWED_EXTENSIONS
            )
            if errs.any?
              error = errs.first
              raise ActiveRecord::Rollback
            end

            title = row[:title].to_s.strip
            title = default_title(file, index) if title.blank?

            meeting_date = parse_optional_date(row[:meeting_date])

            meeting = project.meetings.build(
              title: title,
              meeting_date: meeting_date,
              status: :processing,
              processing_error: nil
            )
            unless meeting.save
              error = meeting.errors.full_messages.to_sentence
              raise ActiveRecord::Rollback
            end

            fmt = File.extname(file.original_filename.to_s).delete(".").downcase
            transcript = Transcript.new(
              meeting: meeting,
              file_name: file.original_filename.to_s,
              file_format: fmt
            )
            unless transcript.save
              error = transcript.errors.full_messages.to_sentence
              raise ActiveRecord::Rollback
            end
            transcript.file.attach(file)

            transcript_ids << transcript.id
            meetings << meeting
          end
        end

        if error.present?
          return Result.new(success: false, meetings: [], error: error)
        end

        transcript_ids.each { |id| TranscriptProcessingJob.perform_later(id) }
        Result.new(success: true, meetings: meetings, error: nil)
      end

      private
        def default_title(file, index)
          base = File.basename(file.original_filename.to_s, ".*")
          (base.presence || "Meeting #{index + 1}").truncate(200, omission: "")
        end

        def parse_optional_date(value)
          return nil if value.blank?

          d = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
          d
        rescue ArgumentError
          nil
        end
    end
  end
end
