module MeetingPipeline
  CACHE_TTL = 1.day

  class << self
    def mark_embed!(meeting_id)
      Rails.cache.write(cache_key(meeting_id, :embed), true, expires_in: CACHE_TTL)
    end

    def mark_extract!(meeting_id)
      Rails.cache.write(cache_key(meeting_id, :extract), true, expires_in: CACHE_TTL)
      finalize_if_ready(Meeting.find(meeting_id))
    end

    def mark_sentiment!(meeting_id)
      Rails.cache.write(cache_key(meeting_id, :sentiment), true, expires_in: CACHE_TTL)
      finalize_if_ready(Meeting.find(meeting_id))
    end

    def finalize_if_ready(meeting)
      id = meeting.id
      return unless Rails.cache.read(cache_key(id, :embed))
      return unless Rails.cache.read(cache_key(id, :extract))
      return unless Rails.cache.read(cache_key(id, :sentiment))

      meeting.update!(status: :completed)
      MeetingProcessingChannel.broadcast_to(meeting, { step: "complete", status: "completed" })
      meeting.broadcast_card_refresh!
      %i[embed extract sentiment].each { |p| Rails.cache.delete(cache_key(id, p)) }
    end

    def cache_key(meeting_id, part)
      "meeting_pipeline:#{meeting_id}:#{part}"
    end
  end
end
