# Meeting Intelligence Hub

## Title
Meeting Intelligence Hub: AI-Powered Meeting Transcript Analysis and Insights

## Demo

**[Open the interactive demo (Supademo)](https://app.supademo.com/embed/cmnlbv7242us7aburyyp5v4nm?embed_v=2&utm_source=embed)**

## The Problem
Teams spend significant time reviewing long meeting transcripts to find action items,
decisions, and key discussion points. Important context is often missed, and manually
summarizing outcomes slows down execution after meetings.

## The Solution
Meeting Intelligence Hub is a Rails 8 application built around **projects** and **meetings**.
You upload or import transcripts, and the pipeline chunks the text, generates embeddings, and
runs LLM extraction in the background (Solid Queue) so the UI stays responsive. From there
you get a structured view of what the meeting produced—not just a wall of text.

**Discovery and analysis**

- **Extracted items** — The system proposes actions and decisions pulled from the transcript.
  You can review, edit, or remove items so the record matches what your team actually agreed to.
- **Semantic search** — Chunks are stored with vectors (pgvector), so you can find relevant
  moments by meaning, not only exact keywords.
- **Meeting chat** — Ask questions in a chat session scoped to a single meeting’s context,
  or use **project-level chat** when you want answers that can draw on multiple meetings in
  the same project.
- **Sentiment** — Explore tone over time and by speaker to spot friction or enthusiasm at a glance.

**Closing the loop**

- **Follow-up drafts** — Generate email drafts from open action items, tune subject and body,
  then confirm to send. An **assignee email book** maps speaker names to addresses so “who
  owns this?” can resolve to the right inbox. Delivery uses Action Mailer (e.g. Postmark in
  production, with optional Resend fallback); see the Email section below.
- **Reprocess** — When you fix a transcript or change upstream settings, you can re-run
  extraction and related processing for a meeting instead of starting over.

Together, these pieces move teams from “read the whole transcript” to “see decisions and
actions, search and ask questions, follow up by email, and sanity-check sentiment”—with
sign-in, passwords, and per-project organization so work stays separated.

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

### Email (follow-up messages)

Outbound mail uses **Action Mailer** with a small central config in `app/models/outbound_mail_config.rb`.

| Setup | When it is used |
| --- | --- |
| **Postmark (HTTPS API)** | Recommended in production. Set `POSTMARK_API_TOKEN` or `POSTMARK_SERVER_API_TOKEN`. Delivery uses the Postmark gem’s API, not SMTP. |
| **Resend (HTTPS API, optional fallback)** | If `RESEND_API_KEY` is set *and* Postmark is primary, a failed Postmark send is retried once via Resend (`MailDeliveryResendFallback`, `ResendApiSender`). Envelope `From` uses `RESEND_SHARED_FROM_EMAIL` (default `onboarding@resend.dev`); the original sender becomes `Reply-To`. |
| **Generic SMTP** | Used when **no** Postmark token is set (e.g. MailHog, corporate relay). Configure `SMTP_ADDRESS` and related `SMTP_*` variables. |
| **Development file delivery** | In development, if neither Postmark nor SMTP is configured, messages are written as `.eml` files under `tmp/mail/`. |

Follow-up sends run in **`FollowupSendJob`** (Solid Queue). Use `bin/dev` (or `bin/jobs`) so a worker processes the queue; alternatively set `DEV_INLINE_JOBS=1` when running `bin/rails server` for in-process jobs. Inspect configuration with `bin/rails mail:diag`.

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

**Email (for sending follow-up mail from the app):**
- **Postmark (recommended):** `POSTMARK_API_TOKEN` or `POSTMARK_SERVER_API_TOKEN` — [Postmark](https://account.postmarkapp.com/)
- **Resend (optional fallback after Postmark errors):** `RESEND_API_KEY` — [Resend](https://resend.com); optional `RESEND_SHARED_FROM_EMAIL` (shared sender when retrying via Resend)
- **SMTP (no Postmark):** `SMTP_ADDRESS` and related `SMTP_*` keys (see `.env.example`)
- **Production links in emails:** `MAILER_DEFAULT_HOST` (public hostname)
- **Verified sender fallback:** `FOLLOWUP_FROM_EMAIL` / `FOLLOWUP_FROM_NAME` when needed (see comments in `.env.example`)

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
