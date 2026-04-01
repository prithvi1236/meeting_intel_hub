class TranscriptsController < ApplicationController
  include ProjectScoped

  before_action :set_project
  before_action :set_meeting

  def create
    uploaded = params[:transcript_file]
    errors = TranscriptUploadValidator.validate(uploaded)
    if errors.any?
      redirect_to project_path(@project), alert: errors.first
      return
    end

    fmt = File.extname(uploaded.original_filename).delete(".").downcase

    transcript_id = nil
    ActiveRecord::Base.transaction do
      @meeting.transcript&.destroy!
      transcript = Transcript.create!(
        meeting: @meeting,
        file_name: uploaded.original_filename,
        file_format: fmt
      )
      transcript.file.attach(uploaded)
      transcript_id = transcript.id

      @meeting.update!(status: :processing, processing_error: nil)
    end
    TranscriptProcessingJob.perform_later(transcript_id)

    redirect_to project_path(@project), notice: "Transcript uploaded."
  end

  private
    def set_meeting
      @meeting = @project.meetings.find(params[:meeting_id])
    end
end
