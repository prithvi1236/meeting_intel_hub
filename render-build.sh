#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

if [ -n "${DATABASE_DIRECT_URL}" ]; then
  DATABASE_URL="${DATABASE_DIRECT_URL}" bundle exec rails db:migrate
else
  bundle exec rails db:migrate
fi
