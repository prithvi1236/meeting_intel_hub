# frozen_string_literal: true

class TranscriptPreviewsController < ApplicationController
  before_action :set_project

  def create
    uploaded = params[:transcript_file]
    unless uploaded.respond_to?(:original_filename)
      return render json: { error: "Choose a file." }, status: :unprocessable_entity
    end

    result = TranscriptPreviewService.call(uploaded)

    if result[:ok]
      render json: result.except(:ok), status: :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end
end
