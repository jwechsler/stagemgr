#!/bin/bash
# SessionStart hook for Claude Code on the web.
# Installs system libraries, generates local config from examples, installs gems,
# and prepares the test database so RSpec can run out of the box.
# Idempotent and non-interactive — safe to run multiple times.
set -euo pipefail

# Only run in the remote (Claude Code on the web) environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

echo "[session-start] Installing system libraries (libmariadb-dev, libvips, build tools)..."
export DEBIAN_FRONTEND=noninteractive
# apt-get update may report errors from unrelated third-party PPAs; tolerate them
# since the packages we need come from the main Ubuntu repositories.
apt-get update -y || true
apt-get install -y --no-install-recommends \
  libmariadb-dev \
  libvips42 \
  build-essential \
  pkg-config

echo "[session-start] Generating local config files from examples (if missing)..."
# Config files (database.yml, server.yml, ticket_print.yml, my_emma_credentials.yml, ...)
# are gitignored; generate them from the checked-in *.yml.example templates.
for example in config/*.yml.example; do
  [ -e "$example" ] || continue
  target="${example%.example}"
  if [ ! -e "$target" ]; then
    cp "$example" "$target"
    echo "[session-start]   created $target"
  fi
done

echo "[session-start] Installing Ruby gems (bundle install)..."
bundle install

echo "[session-start] Preparing the test database (create + migrate)..."
# There is no committed db/schema.rb, so the schema is built from migrations.
RAILS_ENV=test bin/rails db:create db:migrate

# The gem executable directory (where the rspec binstub lives) is not on PATH in
# this environment, so `bundle exec rspec` / `rspec` fail to resolve the command.
# Persist it onto PATH for the session so the normal test commands work.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  gem_bindir="$(ruby -e 'print Gem.bindir')"
  echo "export PATH=\"${gem_bindir}:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  echo "[session-start]   added ${gem_bindir} to PATH (via CLAUDE_ENV_FILE)"
fi

echo "[session-start] Done."
