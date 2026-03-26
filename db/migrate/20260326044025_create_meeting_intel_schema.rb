class CreateMeetingIntelSchema < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :projects, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.string :slug, null: false
      t.integer :meetings_count, null: false, default: 0
      t.integer :total_action_items_count, null: false, default: 0
      t.float :overall_sentiment_score

      t.timestamps
    end
    add_index :projects, :slug, unique: true
    add_index :projects, :user_id

    create_table :meetings, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.date :meeting_date
      t.integer :duration_seconds
      t.integer :speaker_count
      t.integer :word_count
      t.float :overall_sentiment_score
      t.jsonb :sentiment_data, default: {}
      t.string :status, null: false, default: "pending"
      t.text :processing_error

      t.timestamps
    end
    add_index :meetings, [ :project_id, :meeting_date ]
    add_index :meetings, :status

    create_table :transcripts, id: :uuid do |t|
      t.references :meeting, null: false, foreign_key: true, type: :uuid
      t.string :file_name
      t.string :file_format
      t.text :raw_content
      t.jsonb :parsed_segments, default: []
      t.integer :total_speakers
      t.string :language_code, null: false, default: "en"

      t.timestamps
    end
    add_index :transcripts, :meeting_id, unique: true

    create_table :transcript_chunks, id: :uuid do |t|
      t.references :transcript, null: false, foreign_key: true, type: :uuid
      t.references :meeting, null: false, foreign_key: true, type: :uuid
      t.text :content, null: false
      t.string :speaker_name
      t.integer :start_time
      t.integer :end_time
      t.integer :chunk_index
      t.column :embedding, :vector, limit: 768
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    add_index :transcript_chunks, [ :meeting_id, :chunk_index ]

    create_table :extracted_items, id: :uuid do |t|
      t.references :meeting, null: false, foreign_key: true, type: :uuid
      t.references :transcript_chunk, null: true, foreign_key: true, type: :uuid
      t.string :item_type, null: false
      t.text :description, null: false
      t.string :owner
      t.date :due_date
      t.float :confidence_score
      t.text :source_quote
      t.integer :source_timestamp
      t.string :status, null: false, default: "open"
      t.integer :position

      t.timestamps
    end
    add_index :extracted_items, [ :meeting_id, :item_type ]
    add_index :extracted_items, [ :meeting_id, :status ]

    create_table :chat_sessions, id: :uuid do |t|
      t.references :meeting, null: true, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :title

      t.timestamps
    end
    add_index :chat_sessions, [ :project_id, :meeting_id ]

    create_table :chat_messages, id: :uuid do |t|
      t.references :chat_session, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false
      t.text :content
      t.jsonb :citations, default: []

      t.timestamps
    end
    add_index :chat_messages, :chat_session_id

    create_table :speakers, id: :uuid do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :display_name
      t.string :role
      t.string :email
      t.float :average_sentiment
      t.integer :meetings_count, null: false, default: 0

      t.timestamps
    end
    add_index :speakers, [ :project_id, :name ]

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          CREATE INDEX index_transcript_chunks_on_embedding_hnsw
          ON transcript_chunks USING hnsw (embedding vector_cosine_ops)
        SQL
      end
      dir.down do
        execute "DROP INDEX IF EXISTS index_transcript_chunks_on_embedding_hnsw"
      end
    end
  end
end
