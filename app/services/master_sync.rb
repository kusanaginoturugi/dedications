# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class MasterSync
  class FetchError < StandardError; end

  Result = Struct.new(:count, :master_updated_at, keyword_init: true)

  def self.run
    new.run
  end

  def initialize(base_url: Rails.application.config.masters_url)
    @base_url = base_url.to_s.sub(%r{/+\z}, "")
  end

  def run
    body = fetch_fellowships
    rows = body.fetch("data")

    ActiveRecord::Base.transaction do
      rows.each { |row| upsert(row) }
    end

    Result.new(count: rows.size, master_updated_at: body["updated_at"])
  end

  private

  def fetch_fellowships
    uri = URI.parse("#{@base_url}/api/fellowships")
    response = Net::HTTP.get_response(uri)
    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "masters /api/fellowships returned #{response.code}"
    end

    JSON.parse(response.body)
  end

  # enabled は同期で触らない (運用フラグ)。
  # dedications では正式名を使うので name に master.name (正式名) を入れる。
  def upsert(row)
    fellowship = Fellowship.find_or_initialize_by(id: row.fetch("id"))
    fellowship.code = row["code"]
    fellowship.old_code = row["old_code"]
    fellowship.name = row["name"]
    fellowship.save!
  end
end
