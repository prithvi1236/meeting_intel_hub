# Demo data for Meeting Intelligence Hub (no live API calls required).
# Run: bin/rails db:seed

def emb
  Array.new(768) { |i| (Math.sin(i * 0.02) * 0.001).round(6) }
end

def sample_segments(prefix:)
  [
    { "speaker" => "Alex", "text" => "#{prefix}: We agreed to ship the dashboard redesign next Friday.", "start_time" => 0, "end_time" => 45 },
    { "speaker" => "Jordan", "text" => "I'll own the API integration and document the endpoints.", "start_time" => 46, "end_time" => 120 },
    { "speaker" => "Alex", "text" => "Decision: we are standardizing on PostgreSQL for the analytics store.", "start_time" => 121, "end_time" => 200 },
    { "speaker" => "Sam", "text" => "I'm frustrated we slipped twice; we need clearer acceptance criteria.", "start_time" => 201, "end_time" => 280 },
    { "speaker" => "Jordan", "text" => "Action: Sam will draft criteria by Wednesday.", "start_time" => 281, "end_time" => 340 }
  ]
end

def sentiment_demo
  {
    "timeline" => [
      {
        "window_start" => 0,
        "window_end" => 180,
        "score" => 0.65,
        "label" => "consensus",
        "dominant_emotion" => "engaged",
        "speakers" => %w[Alex Jordan],
        "transcript_snippet" => "Alex: We agreed to ship the dashboard redesign next Friday.\nJordan: I'll own the API integration."
      },
      {
        "window_start" => 180,
        "window_end" => 360,
        "score" => -0.2,
        "label" => "tension",
        "dominant_emotion" => "frustrated",
        "speakers" => %w[Sam],
        "transcript_snippet" => "Sam: I'm frustrated we slipped twice; we need clearer acceptance criteria."
      }
    ],
    "per_speaker" => [
      { "name" => "Alex", "average_score" => 0.55, "dominant_emotion" => "engaged", "segment_count" => 2 },
      { "name" => "Jordan", "average_score" => 0.4, "dominant_emotion" => "cautious", "segment_count" => 2 },
      { "name" => "Sam", "average_score" => -0.35, "dominant_emotion" => "frustrated", "segment_count" => 1 }
    ],
    "overall_score" => 0.35
  }
end

user = User.find_or_initialize_by(email: "demo@example.com")
user.assign_attributes(
  name: "Demo User",
  password: "password",
  password_confirmation: "password"
)
user.save!

projects_data = [
  {
    name: "Product Team Q2",
    description: "Roadmap, discovery, and launch planning.",
    meetings: [
      { title: "Q2 roadmap review", theme: "roadmap" },
      { title: "Sprint 24 planning", theme: "sprint" },
      { title: "Retro — shipping pains", theme: "retro" }
    ]
  },
  {
    name: "Engineering Standup",
    description: "Weekly technical sync and blockers.",
    meetings: [
      { title: "Infra reliability review", theme: "infra" },
      { title: "API deprecation plan", theme: "api" },
      { title: "Hiring pipeline check-in", theme: "hiring" }
    ]
  }
]

projects_data.each do |pdata|
  project = Project.find_or_initialize_by(user: user, slug: pdata[:name].parameterize)
  project.assign_attributes(name: pdata[:name], description: pdata[:description])
  project.save!

  pdata[:meetings].each do |mdata|
    meeting = Meeting.find_or_initialize_by(project: project, title: mdata[:title])
    meeting.assign_attributes(
      meeting_date: Date.current - rand(1..30),
      status: :completed,
      speaker_count: 3,
      word_count: 420,
      overall_sentiment_score: 0.35,
      sentiment_data: sentiment_demo
    )
    meeting.save!

    segments = sample_segments(prefix: mdata[:theme])
    raw = segments.map { |s| "#{s['speaker']}: #{s['text']}" }.join("\n")

    transcript = meeting.transcript || meeting.build_transcript
    transcript.assign_attributes(
      file_name: "#{mdata[:theme]}.txt",
      file_format: "txt",
      raw_content: raw,
      parsed_segments: segments,
      total_speakers: segments.map { |s| s["speaker"] }.uniq.size,
      language_code: "en"
    )
    transcript.save!

    meeting.transcript_chunks.destroy_all
    segments.each_with_index do |seg, idx|
      meeting.transcript_chunks.create!(
        transcript: transcript,
        content: "#{seg['speaker']}: #{seg['text']}",
        speaker_name: seg["speaker"],
        start_time: seg["start_time"],
        end_time: seg["end_time"],
        chunk_index: idx,
        embedding: emb,
        metadata: { "speakers_in_chunk" => [ seg["speaker"] ] }
      )
    end

    meeting.extracted_items.destroy_all
    items = [
      { type: :decision, desc: "Ship redesigned dashboard next Friday.", quote: segments[0]["text"], ts: 10 },
      { type: :decision, desc: "Standardize on PostgreSQL for analytics.", quote: segments[2]["text"], ts: 130 },
      { type: :action_item, desc: "Document API endpoints", owner: "Jordan", quote: segments[1]["text"], ts: 60 },
      { type: :action_item, desc: "Draft acceptance criteria", owner: "Sam", quote: segments[4]["text"], ts: 300 },
      { type: :decision, desc: "Weekly reliability review continues.", quote: segments[0]["text"], ts: 5 }
    ]
    items.each_with_index do |it, i|
      meeting.extracted_items.create!(
        item_type: it[:type],
        description: it[:desc],
        owner: it[:owner],
        confidence_score: 0.88,
        source_quote: it[:quote],
        source_timestamp: it[:ts],
        status: :open,
        position: i + 1
      )
    end
  end
end

# Demo chat on first meeting of first project
p1 = user.projects.find_by!(slug: "product-team-q2")
first_meeting = p1.meetings.find_by!(title: "Q2 roadmap review")
session = ChatSession.find_or_create_by!(project: p1, meeting: first_meeting) do |s|
  s.title = "Meeting chat"
end
session.chat_messages.destroy_all
session.chat_messages.create!(role: :user, content: "What decisions were made about the database?")
session.chat_messages.create!(
  role: :assistant,
  content: "The team decided to standardize on PostgreSQL for the analytics store.",
  citations: [
    {
      "chunk_id" => first_meeting.transcript_chunks.first&.id,
      "meeting_title" => first_meeting.title,
      "timestamp" => 130,
      "quote" => "Decision: we are standardizing on PostgreSQL"
    }
  ]
)

# Cross-meeting project chat
proj_chat = ChatSession.find_or_create_by!(project: p1, meeting_id: nil) do |s|
  s.title = "Project overview"
end
proj_chat.chat_messages.destroy_all
proj_chat.chat_messages.create!(role: :user, content: "Summarize themes across meetings.")
proj_chat.chat_messages.create!(
  role: :assistant,
  content: "Discussions mix roadmap alignment, sprint commitments, and retros on delivery friction.",
  citations: []
)

# Refresh counter caches
user.projects.find_each do |pr|
  pr.update_columns(
    meetings_count: pr.meetings.count,
    total_action_items_count: ExtractedItem.action_items.joins(:meeting).where(meetings: { project_id: pr.id }).count
  )
  scores = pr.meetings.completed.where.not(overall_sentiment_score: nil).pluck(:overall_sentiment_score)
  pr.update_columns(overall_sentiment_score: scores.empty? ? nil : (scores.sum.to_f / scores.size))
end

puts "Seeded demo@example.com / password — #{Project.count} projects, #{Meeting.count} meetings."
