# Meeting Intelligence Hub

Rails 8 app for transcript ingestion, AI extraction, chat over meetings, and sentiment views.

## Prerequisites

- Ruby 3.4+ (see `.ruby-version`)
- PostgreSQL with the **pgvector** extension
- Optional: Redis (e.g. for Kredis / future caching)

## Configuration

Copy [`.env.example`](.env.example) and set:

- **`GROQ_API_KEY`** — from [Groq Console](https://console.groq.com/keys), used for:
  - **Action/decision extraction**
  - **Meeting chat responses**
- **`HUGGINGFACE_API_TOKEN`** — from [Hugging Face](https://huggingface.co/settings/tokens), used for:
  - **Embeddings** (`BAAI/bge-base-en-v1.5`, 768 dimensions) for semantic search over transcript chunks
  - **Sentiment analysis** (`cardiffnlp/twitter-roberta-base-sentiment-latest`) for timeline/speaker sentiment

Optional:

- `GROQ_CHAT_MODEL` — override chat model (default `llama-3.3-70b-versatile`)
- `GROQ_EXTRACT_MODEL` — override extraction model (defaults to `GROQ_CHAT_MODEL`)
- `HF_EMBEDDING_MODEL` — override embeddings model (default `BAAI/bge-base-en-v1.5`)
- `HF_SENTIMENT_MODEL` — override sentiment model (`text-classification` pipeline)

## Database

```bash
bin/rails db:prepare
```

Ensure `CREATE EXTENSION vector` runs (included in the schema migration).

> `transcript_chunks.embedding` is configured for **768** dimensions. Keep your embedding model aligned with this dimension, or add a migration if you choose a different model size.

## Run locally

```bash
bin/dev
```

Starts the web server, Tailwind watcher, and Solid Queue worker (see `Procfile.dev`).

## Tests

```bash
bundle exec rspec
```
