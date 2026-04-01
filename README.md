# Meeting Intelligence Hub

## Title
Meeting Intelligence Hub: AI-Powered Meeting Transcript Analysis and Insights

## The Problem
Teams spend significant time reviewing long meeting transcripts to find action items,
decisions, and key discussion points. Important context is often missed, and manually
summarizing outcomes slows down execution after meetings.

## The Solution
Meeting Intelligence Hub is a Rails 8 application that ingests meeting transcripts and
uses AI services to transform raw conversations into actionable insights. It supports
automated action/decision extraction, semantic search over transcript chunks, interactive
chat with meeting context, and sentiment views by timeline and speaker.

## Tech Stack

### Programming Languages
- Ruby
- JavaScript

### Frameworks and Runtime
- Ruby on Rails 8
- Hotwire (Turbo + Stimulus)
- Tailwind CSS

### Databases and Storage
- PostgreSQL
- pgvector extension (vector similarity search)

### APIs and Third-Party Tools
- Groq API (LLM-powered extraction and chat)
- Hugging Face Inference API (embeddings + sentiment analysis)
- Solid Queue (background jobs)

## Setup Instructions

### 1) Install dependencies

```bash
bundle install
```

If you do not already have JavaScript dependencies installed:

```bash
npm install
```

### 2) Configure environment variables

Copy the example environment file:

```bash
cp .env.example .env
```

Update `.env` with:
- `GROQ_API_KEY` from [Groq Console](https://console.groq.com/keys)
- `HUGGINGFACE_API_TOKEN` from [Hugging Face](https://huggingface.co/settings/tokens)

Optional overrides:
- `GROQ_CHAT_MODEL` (default: `llama-3.3-70b-versatile`)
- `GROQ_EXTRACT_MODEL` (defaults to `GROQ_CHAT_MODEL`)
- `HF_EMBEDDING_MODEL` (default: `BAAI/bge-base-en-v1.5`)
- `HF_SENTIMENT_MODEL`

### 3) Prepare the database

```bash
bin/rails db:prepare
```

This project requires PostgreSQL with `pgvector` enabled. The migration includes
`CREATE EXTENSION vector`.

### 4) Run the project locally

```bash
bin/dev
```

This starts the Rails server, Tailwind watcher, and Solid Queue worker (via
`Procfile.dev`).

### 5) Run tests (optional but recommended)

```bash
bundle exec rspec
```
