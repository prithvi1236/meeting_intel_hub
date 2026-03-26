class TranscriptsController < ApplicationController
  before_action :set_project
  before_action :set_meeting

  def create
    uploaded = params[:transcript_file]
    unless uploaded.present?
      return redirect_to project_meeting_path(@project, @meeting), alert: "Choose a file."
    end
    unless allowed_extension?(uploaded.original_filename)
      return respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "transcript-upload-errors",
            partial: "shared/inline_error",
            locals: { message: "Allowed formats: .txt, .vtt, .srt" }
          )
        end
        format.html { redirect_to project_meeting_path(@project, @meeting), alert: "Invalid file type." }
      end
    end

    fmt = File.extname(uploaded.original_filename).delete(".").downcase

    ActiveRecord::Base.transaction do
      @meeting.transcript&.destroy!
      transcript = Transcript.create!(
        meeting: @meeting,
        file_name: uploaded.original_filename,
        file_format: fmt
      )
      transcript.file.attach(uploaded)

      @meeting.update!(status: :processing, processing_error: nil)
      TranscriptProcessingJob.perform_later(transcript.id)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "transcript-upload-zone",
          partial: "meetings/transcript_upload",
          locals: { project: @project, meeting: @meeting }
        )
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

    def allowed_extension?(name)
      %w[txt vtt srt].include?(File.extname(name).delete(".").downcase)
    end
end
