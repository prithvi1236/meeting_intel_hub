class MeetingsController < ApplicationController
  before_action :set_project
  before_action :set_meeting, only: %i[show edit update destroy sentiment reprocess]

  def index
    redirect_to @project
  end

  def show
    @transcript = @meeting.transcript
    @extracted_items = @meeting.extracted_items.order(:position, :created_at)
    @chat_session = ChatSession.find_or_create_by!(project: @project, meeting: @meeting) do |s|
      s.title = "Meeting chat"
    end
    @messages = @chat_session.chat_messages.order(:created_at)
  end

  def new
    @meeting = @project.meetings.build
  end

  def edit
  end

  def create
    @meeting = @project.meetings.build(meeting_params)
    uploaded = params[:transcript_file]

    if uploaded.present? && !allowed_extension?(uploaded.original_filename)
      @meeting.errors.add(:base, "Allowed formats: .txt, .vtt, .srt")
      return render :new, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @meeting.save!
      if uploaded.present?
        fmt = File.extname(uploaded.original_filename).delete(".").downcase
        tr = @meeting.create_transcript!(file_name: uploaded.original_filename, file_format: fmt)
        tr.file.attach(uploaded)
        TranscriptProcessingJob.perform_later(tr.id)
      end
    end
    redirect_to project_meeting_path(@project, @meeting), notice: "Meeting created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def update
    if @meeting.update(meeting_params)
      redirect_to [ @project, @meeting ], notice: "Meeting updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @meeting.destroy
    redirect_to project_path(@project), notice: "Meeting removed."
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
      redirect_to [ @project, @meeting ], notice: "Reprocessing started."
    else
      redirect_to [ @project, @meeting ], alert: "No transcript to reprocess."
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

    def allowed_extension?(name)
      %w[txt vtt srt].include?(File.extname(name).delete(".").downcase)
    end
end
