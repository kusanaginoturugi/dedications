#!/usr/bin/env bash
set -euxo pipefail

APP_ROOT="/home/ubuntu/dedications"
RUBY_BIN="/home/ubuntu/.local/share/mise/installs/ruby/3.4.8/bin"
MISE_BIN="/home/ubuntu/.local/bin"
SERVICE_NAME="dedications.service"
HEALTHCHECK_URL="http://127.0.0.1:3000/up"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

report_failure() {
  local line="$1"
  local exit_code="$2"
  set +x
  printf '\n[deploy] failed at line %s with exit code %s\n' "$line" "$exit_code" >&2
  git status --short || true
  exit "$exit_code"
}

trap 'report_failure "$LINENO" "$?"' ERR

cd "$APP_ROOT"

export HOME="/home/ubuntu"
export PATH="$MISE_BIN:$RUBY_BIN:$PATH"
export RAILS_ENV="production"
export BUNDLE_GEMFILE="$APP_ROOT/Gemfile"
export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

git config core.fileMode false

log "Fetching latest code"
git fetch origin
git status --short || true
git reset --hard origin/main

log "Installing gems"
bundle config set deployment true
bundle config set without 'development test'
bundle install

log "Running database migrations"
bin/rails db:migrate

log "Precompiling assets"
bin/rails assets:clobber
bin/rails assets:precompile

log "Restarting application service"
rm -f "$APP_ROOT"/tmp/pids/*.pid
sudo -n /usr/bin/systemctl restart "$SERVICE_NAME"
sudo -n /usr/bin/systemctl is-active "$SERVICE_NAME"

log "Checking application health"
sleep 5
curl --fail --silent --show-error --retry 5 --retry-delay 2 "$HEALTHCHECK_URL" > /dev/null
