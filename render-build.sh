#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Use DATABASE_URL only. Supabase "direct" (port 5432) often resolves to IPv6, which Render's
# build network cannot reach. Use the pooler URI (e.g. :6543) for migrate; in Supabase, pick
# "Session" pool mode if "Transaction" mode blocks migrations.
bundle exec rails db:migrate
