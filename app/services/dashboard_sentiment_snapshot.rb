# frozen_string_literal: true

# Aggregates meeting sentiment for the dashboard: per-project "focus" rows
# (last scored meeting vs average of prior scored meetings).
class DashboardSentimentSnapshot
  FocusRow = Data.define(:project, :last_meeting, :last_score, :prior_avg, :swing) do
    # Lower is more concerning: negative swing or low lone meeting score.
    def rank_key
      swing.nil? ? last_score : swing
    end
  end

  class << self
    def focus_rows(user, limit: 5)
      meetings = scored_completed_meetings_for(user).includes(:project).to_a
      by_project = meetings.group_by(&:project_id)
      rows = []

      by_project.each_value do |list|
        sorted = sort_meetings_newest_first(list)
        last_m = sorted.first
        prior = sorted.drop(1)
        next unless last_m

        last_score = last_m.overall_sentiment_score.to_f
        prior_avg = if prior.empty?
          nil
        else
          prior.sum(&:overall_sentiment_score) / prior.size.to_f
        end
        swing = prior_avg.nil? ? nil : (last_score - prior_avg)

        rows << FocusRow.new(
          project: last_m.project,
          last_meeting: last_m,
          last_score: last_score,
          prior_avg: prior_avg,
          swing: swing
        )
      end

      rows.sort_by(&:rank_key).first(limit)
    end

    private
      def scored_completed_meetings_for(user)
        Meeting.joins(:project).where(projects: { user_id: user.id }).completed.where.not(overall_sentiment_score: nil)
      end

      def sort_meetings_newest_first(meetings)
        meetings.sort_by do |m|
          d = m.meeting_date
          [ d ? -d.jd : Float::INFINITY, -m.created_at.to_f ]
        end
      end
  end
end
