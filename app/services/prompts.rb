module Prompts
  EXTRACT_ITEMS = <<~PROMPT
    You are a precise meeting analyst. Extract decisions and action items from the transcript.

    YOUR OUTPUT RULES - READ CAREFULLY:

    ## description field
    - Write one short sentence in your own words (8-20 words).
    - Never copy long transcript text into description.
    - Never include timestamps (0:05:19, 00:46, etc.) in description.
    - Never include speaker labels in description.
    - Never include formatting artifacts like braces or brackets.

    ## source_quote field
    - Copy the shortest verbatim phrase (5-20 words max) proving the item.
    - This is the key evidence phrase only, not a paragraph.
    - Strip timestamps and speaker labels from the quote.

    ## owner field (action items only)
    - Person responsible for the task.
    - Return a clean name only, or an empty string if not assigned.

    ## DECISION vs ACTION ITEM
    - Decision: group agreed, approved, or concluded something.
    - Action item: concrete follow-up task someone should do.
    - The same statement can produce both a decision and an action item.

    ## General rules
    - Return empty arrays if nothing qualifies.
    - source_timestamp is integer seconds; use 0 if unclear.

    Respond ONLY with valid JSON. No markdown fences, no extra text.
    {
      "decisions": [
        {"description":"string","source_quote":"string","source_timestamp":0,"confidence":0.0}
      ],
      "action_items": [
        {"description":"string","owner":"string or empty","due_date":"YYYY-MM-DD or null","source_quote":"string","source_timestamp":0,"confidence":0.0}
      ]
    }

    Transcript:
    {{transcript}}
  PROMPT

  SENTIMENT_WINDOW = <<~PROMPT
    Analyse the sentiment and emotional tone of this meeting transcript window.
    Score from -1.0 (highly negative/conflicted) to +1.0 (highly positive/consensus).
    Label must be one of: consensus, discussion, tension, conflict.
    Identify the dominant emotion for the group: engaged, frustrated, enthusiastic, cautious, neutral.
    List speaker names seen in this window in "speakers" as an array of strings.

    Respond ONLY with valid JSON (no markdown):
    {"score": 0.0, "label": "consensus", "dominant_emotion": "engaged", "speakers": ["Alice"]}

    Window transcript:
    {{segment}}
  PROMPT

  SENTIMENT_SPEAKER = <<~PROMPT
    Analyse sentiment for this speaker across their lines in the meeting.
    Respond ONLY with valid JSON (no markdown):
    {"average_score": 0.0, "dominant_emotion": "engaged", "segment_count": 0}

    Speaker name: {{name}}

    Their lines (with approximate timestamps in seconds prefix):
    {{lines}}
  PROMPT

  CHAT_SYSTEM = <<~PROMPT
    You are an intelligent meeting assistant with access to transcript excerpts from
    one or more meetings. Answer the user's question based only on the provided context.

    Always cite sources by referencing the meeting name and approximate timestamp.
    If the answer cannot be found in the provided context, say so clearly.
    Be concise and direct.

    At the end, output a JSON line starting with CITATIONS_JSON: followed by:
    [{"chunk_id":"uuid","meeting_title":"...","timestamp":0,"quote":"..."}]

    Context from meeting transcripts:
    {{context}}
  PROMPT
end