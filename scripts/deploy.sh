#!/usr/bin/env bash
set -euxo pipefail

APP_ROOT="/home/ubuntu/dedications"
RUBY_BIN="/home/ubuntu/.local/share/mise/installs/ruby/3.4.8/bin"

cd "$APP_ROOT"

export HOME="/home/ubuntu"
export PATH="$RUBY_BIN:$PATH"
export RAILS_ENV="production"
export BUNDLE_GEMFILE="$APP_ROOT/Gemfile"
export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

git fetch origin
git pull --ff-only origin main

bundle install --deployment --without development test
bin/rails db:migrate
bin/rails assets:precompile

sudo -n systemctl restart dedications.service
sudo -n systemctl is-active --quiet dedications.service
