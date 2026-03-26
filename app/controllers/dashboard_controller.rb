class DashboardController < ApplicationController
  def index
    @projects = current_user.projects.includes(:meetings).ordered
    @total_meetings = Meeting.joins(:project).where(projects: { user_id: current_user.id }).count
    @open_action_items = ExtractedItem.open.action_items.joins(meeting: :project).where(projects: { user_id: current_user.id }).count
    @avg_sentiment = Meeting.joins(:project).where(projects: { user_id: current_user.id }).completed.where.not(overall_sentiment_score: nil).average(:overall_sentiment_score)&.to_f
  end

  def project_stats
    @project = current_user.projects.find(params[:id])
    render :project_stats
  end
end
