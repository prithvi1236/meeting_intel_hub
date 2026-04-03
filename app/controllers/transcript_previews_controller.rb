# frozen_string_literal: true

class TranscriptPreviewsController < ApplicationController
  include ProjectScoped

  before_action :set_project

  def create
    uploaded = params[:transcript_file]
    unless uploaded.respond_to?(:original_filename)
      return render json: { error: "Choose a file." }, status: :unprocessable_content
    end

    result = TranscriptPreviewService.call(uploaded)

    if result[:ok]
      render json: result.except(:ok), status: :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_content
    end
  end

  private
end
