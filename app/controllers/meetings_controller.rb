class MeetingsController < ApplicationController
  include ProjectScoped

  before_action :set_project
  before_action :set_meeting, only: %i[show edit update destroy sentiment reprocess]

  def index
    redirect_to @project
  end

  def show
    return head :forbidden if @meeting.processing?

    @chat_session = @meeting.chat_sessions.find_by(project: @project)
    @chat_session ||= @meeting.chat_sessions.create!(project: @project, title: "Meeting chat")
    @chat_messages = @chat_session.chat_messages.order(:created_at)
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
        return render :new, status: :unprocessable_content
      end
    end

    result = Meetings::CreateWithTranscript.call(meeting: @meeting, uploaded: uploaded)
    transcript_id = result.transcript_id
    TranscriptProcessingJob.perform_later(transcript_id) if transcript_id
    redirect_to project_path(@project), notice: "Meeting created.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def update
    if @meeting.update(meeting_params)
      redirect_to project_meeting_path(@project, @meeting), notice: "Meeting updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
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
    def set_meeting
      @meeting = @project.meetings.find(params[:id])
    end

    def meeting_params
      params.expect(meeting: [ :title, :meeting_date ])
    end
end
