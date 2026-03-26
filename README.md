# Meeting Intelligence Hub

Rails 8 app for transcript ingestion, AI extraction, chat over meetings, and sentiment views.

## Prerequisites

- Ruby 3.4+ (see `.ruby-version`)
- PostgreSQL with the **pgvector** extension
- Optional: Redis (e.g. for Kredis / future caching)

## Configuration

Copy [`.env.example`](.env.example) and set at least:

- **`GEMINI_API_KEY`** — from [Google AI Studio](https://aistudio.google.com/). Used for:
  - **Embeddings** (`text-embedding-004`, 768 dimensions) for semantic search over transcript chunks
  - **Text generation** (default `gemini-2.0-flash`) for extraction, sentiment, and chat

Optional:

- `GEMINI_MODEL` — override the chat/extraction model (default `gemini-2.0-flash`)
- `GEMINI_EMBEDDING_MODEL` — override embeddings (default `text-embedding-004`)

## Database

```bash
bin/rails db:prepare
```

Ensure `CREATE EXTENSION vector` runs (included in the schema migration).

> If you previously ran migrations when `transcript_chunks.embedding` was **1536** dimensions, roll back or recreate the DB before aligning with Gemini’s **768**-dim embeddings, or add a manual migration to alter the column.

## Run locally

```bash
bin/dev
```

Starts the web server, Tailwind watcher, and Solid Queue worker (see `Procfile.dev`).

## Tests

```bash
bundle exec rspec
```
