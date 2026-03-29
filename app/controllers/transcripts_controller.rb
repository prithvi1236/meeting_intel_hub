class TranscriptsController < ApplicationController
  before_action :set_project
  before_action :set_meeting

  def create
    uploaded = params[:transcript_file]
    errors = TranscriptUploadValidator.validate(uploaded)
    if errors.any?
      msg = errors.first
      return respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "transcript-upload-errors",
            partial: "shared/inline_error",
            locals: { message: msg }
          )
        end
        format.html { redirect_to project_meeting_path(@project, @meeting), alert: msg }
      end
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

    respond_to do |format|
      format.turbo_stream do
        @meeting.reload
        render turbo_stream: [
          turbo_stream.replace(
            "transcript-upload-zone",
            partial: "meetings/transcript_upload",
            locals: { project: @project, meeting: @meeting }
          ),
          turbo_stream.replace(
            "transcript-summary",
            partial: "meetings/transcript_summary",
            locals: { project: @project, meeting: @meeting, transcript: @meeting.transcript }
          )
        ]
      end
      format.html { redirect_to project_meeting_path(@project, @meeting), notice: "Transcript uploaded." }
    end
  end

  def destroy
    @meeting.transcript&.destroy
    redirect_to project_meeting_path(@project, @meeting), notice: "Transcript removed."
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:meeting_id])
    end

end
