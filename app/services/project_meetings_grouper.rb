# frozen_string_literal: true

# Groups meetings for project#show (title, day, week, or month buckets).
class ProjectMeetingsGrouper
  class << self
    # @param meetings [Array<Meeting>] (preload :transcript)
    # @param group [String] "title", "day", "week", "month"
    # @param group_sort [String] "latest" or "name"
    # @return [Array<Hash>] { :key, :label, :meetings }
    def call(meetings, group:, group_sort:)
      list = Array(meetings)
      grouped =
        case group.to_s
        when "day"
          list.group_by { |m| day_key(m) }
        when "week"
          list.group_by { |m| week_key(m) }
        when "month"
          list.group_by { |m| month_key(m) }
        else
          list.group_by(&:title)
        end

      grouped.transform_values! { |ms| sort_within_group(ms) }

      ordered_keys =
        if group_sort.to_s == "name"
          sort_keys_by_name(grouped.keys, group)
        else
          sort_keys_by_latest(grouped)
        end

      ordered_keys.map do |key|
        {
          key: key,
          label: human_label(key, group),
          meetings: grouped[key]
        }
      end
    end

    def effective_date(meeting)
      meeting.meeting_date ||
        meeting.transcript&.detected_meeting_date ||
        meeting.created_at.to_date
    end

    private
      def day_key(meeting)
        effective_date(meeting).iso8601
      end

      def week_key(meeting)
        d = effective_date(meeting)
        d.strftime("%G-W%V")
      end

      def month_key(meeting)
        effective_date(meeting).strftime("%Y-%m")
      end

      def sort_within_group(meetings)
        meetings.sort_by do |m|
          d = m.meeting_date || m.transcript&.detected_meeting_date
          [ d ? 0 : 1, d ? -d.jd : 0, -m.created_at.to_i ]
        end
      end

      def max_effective_date_for_group(meetings)
        dates = meetings.map { |m| effective_date(m) }
        dates.max
      end

      def sort_keys_by_latest(grouped)
        grouped.keys.sort_by do |k|
          -max_effective_date_for_group(grouped[k]).jd
        end
      end

      def sort_keys_by_name(keys, group)
        case group.to_s
        when "day", "week", "month"
          keys.sort.reverse
        else
          keys.sort_by { |k| k.to_s.downcase }
        end
      end

      def human_label(key, group)
        case group.to_s
        when "day"
          begin
            Date.iso8601(key.to_s).to_fs(:long)
          rescue ArgumentError
            key.to_s
          end
        when "week"
          y, w = key.to_s.split("-W", 2)
          w ||= "?"
          "Week #{w}, #{y}"
        when "month"
          begin
            y, m = key.to_s.split("-", 2)
            Date.new(y.to_i, m.to_i, 1).strftime("%B %Y")
          rescue ArgumentError, NoMethodError
            key.to_s
          end
        else
          key.to_s
        end
      end
  end
end
