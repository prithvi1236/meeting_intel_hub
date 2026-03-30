class MeetingsController < ApplicationController
  before_action :set_project
  before_action :set_meeting, only: %i[show edit update destroy sentiment reprocess peek]

  def index
    redirect_to @project
  end

  def show
    redirect_to project_path(@project)
  end

  def peek
    return head :forbidden if @meeting.processing?

    render layout: false
  end

  def new
    redirect_to project_path(@project, upload: "1"), status: :see_other
  end

  def edit
  end

  def create
    @meeting = @project.meetings.build(meeting_params)
    uploaded = params[:transcript_file]

    if uploaded.present?
      TranscriptUploadValidator.validate(uploaded).each do |msg|
        @meeting.errors.add(:base, msg)
      end
      if @meeting.errors.any?
        return render :new, status: :unprocessable_entity
      end
    end

    transcript_id = nil
    ActiveRecord::Base.transaction do
      @meeting.save!
      if uploaded.present?
        fmt = File.extname(uploaded.original_filename).delete(".").downcase
        tr = Transcript.create!(
          meeting: @meeting,
          file_name: uploaded.original_filename,
          file_format: fmt
        )
        tr.file.attach(uploaded)
        transcript_id = tr.id
        @meeting.update!(status: :processing, processing_error: nil)
      end
    end
    TranscriptProcessingJob.perform_later(transcript_id) if transcript_id
    redirect_to project_path(@project), notice: "Meeting created.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def update
    if @meeting.update(meeting_params)
      if turbo_frame_request?
        redirect_to peek_project_meeting_path(@project, @meeting), status: :see_other
      else
        redirect_to project_path(@project), notice: "Meeting updated.", status: :see_other
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @meeting.destroy
    redirect_to project_path(@project), notice: "Meeting removed.", status: :see_other
  end

  def sentiment
    respond_to do |format|
      format.json { render json: @meeting.sentiment_data }
    end
  end

  def reprocess
    if (tr = @meeting.transcript)
      @meeting.transcript_chunks.destroy_all
      @meeting.extracted_items.destroy_all
      @meeting.update!(sentiment_data: {}, overall_sentiment_score: nil, status: :processing, processing_error: nil)
      Rails.cache.delete(MeetingPipeline.cache_key(@meeting.id, :embed))
      Rails.cache.delete(MeetingPipeline.cache_key(@meeting.id, :extract))
      Rails.cache.delete(MeetingPipeline.cache_key(@meeting.id, :sentiment))
      TranscriptProcessingJob.perform_later(tr.id)
      redirect_to project_path(@project), notice: "Reprocessing started.", status: :see_other
    else
      redirect_to project_path(@project), alert: "No transcript to reprocess.", status: :see_other
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:id])
    end

    def meeting_params
      params.expect(meeting: [ :title, :meeting_date ])
    end
end
