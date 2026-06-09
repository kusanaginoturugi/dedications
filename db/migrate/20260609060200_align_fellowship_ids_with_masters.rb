# frozen_string_literal: true

class AlignFellowshipIdsWithMasters < ActiveRecord::Migration[8.1]
  OFFSET = 200_000

  def up
    execute "PRAGMA defer_foreign_keys = ON"

    execute "UPDATE orders SET fellowship_id = fellowship_id + #{OFFSET}"
    execute "UPDATE fellowships SET id = id + #{OFFSET}"

    masters_url = Rails.application.config.masters_url.to_s.sub(%r{/+\z}, "")
    require "net/http"
    require "uri"
    require "json"
    response = Net::HTTP.get_response(URI.parse("#{masters_url}/api/fellowships"))
    raise "masters fetch failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    code_to_master_id = JSON.parse(response.body).fetch("data").each_with_object({}) do |row, h|
      h[row["code"].to_s] = row["id"].to_i
    end

    current = select_all("SELECT id, code FROM fellowships").to_a
    current.each do |row|
      new_id = code_to_master_id[row["code"].to_s]
      next unless new_id

      old_id = row["id"]
      next if old_id == new_id

      execute "UPDATE orders SET fellowship_id = #{new_id} WHERE fellowship_id = #{old_id}"
      execute "UPDATE fellowships SET id = #{new_id} WHERE id = #{old_id}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
