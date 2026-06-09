# frozen_string_literal: true

Rails.application.config.masters_url = ENV.fetch(
  "MASTERS_URL",
  "https://osystem-masters.kusanaginoturugi.workers.dev"
)
