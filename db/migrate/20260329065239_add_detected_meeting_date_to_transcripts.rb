class AddDetectedMeetingDateToTranscripts < ActiveRecord::Migration[8.0]
  def change
    add_column :transcripts, :detected_meeting_date, :date
  end
end
