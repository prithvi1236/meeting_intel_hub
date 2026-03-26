class TranscriptChunkerService
  WORDS_PER_CHUNK = 300
  OVERLAP_WORDS = 50

  class << self
    def call(segments, words_per_chunk: WORDS_PER_CHUNK, overlap: OVERLAP_WORDS)
      normalized = Array(segments).map(&:stringify_keys)
      return [] if normalized.empty?

      chunks = []
      words_buffer = []
      chunk_start_time = nil
      chunk_end_time = nil
      speakers_in_chunk = []

      flush = lambda do
        return if words_buffer.empty?

        text = words_buffer.join(" ")
        meta_speakers = speakers_in_chunk.uniq
        chunks << {
          content: text,
          speaker_name: meta_speakers.one? ? meta_speakers.first : meta_speakers.join(", "),
          start_time: chunk_start_time.to_i,
          end_time: chunk_end_time.to_i,
          metadata: {
            "speakers_in_chunk" => meta_speakers,
            "segment_start" => chunk_start_time,
            "segment_end" => chunk_end_time
          }
        }
      end

      normalized.each do |seg|
        speaker = seg["speaker"].presence || "Speaker"
        start_t = seg["start_time"].to_i
        end_t = seg["end_time"].to_i
        seg["text"].to_s.split(/\s+/).each do |w|
          next if w.blank?

          if words_buffer.empty?
            chunk_start_time = start_t
            speakers_in_chunk = [ speaker ]
          elsif !speakers_in_chunk.include?(speaker)
            speakers_in_chunk << speaker
          end
          chunk_end_time = end_t
          words_buffer << w

          if words_buffer.size >= words_per_chunk
            flush.call
            tail = words_buffer.last(overlap)
            words_buffer = tail.dup
            chunk_start_time = start_t
            speakers_in_chunk = [ speaker ]
            chunk_end_time = end_t
          end
        end
      end

      flush.call
      chunks.each_with_index { |c, i| c[:chunk_index] = i }
      chunks
    end
  end
end
