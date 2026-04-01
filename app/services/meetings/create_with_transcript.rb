# frozen_string_literal: true

module Meetings
  class CreateWithTranscript
    Result = Struct.new(:transcript_id, keyword_init: true)

    class << self
      def call(meeting:, uploaded:)
        transcript_id = nil

        ActiveRecord::Base.transaction do
          meeting.save!

          if uploaded.present?
            fmt = File.extname(uploaded.original_filename).delete(".").downcase
            tr = Transcript.create!(
              meeting: meeting,
              file_name: uploaded.original_filename,
              file_format: fmt
            )
            tr.file.attach(uploaded)
            transcript_id = tr.id
            meeting.update!(status: :processing, processing_error: nil)
          end
        end

        Result.new(transcript_id: transcript_id)
      end
    end
  end
end
