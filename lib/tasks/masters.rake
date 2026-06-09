# frozen_string_literal: true

namespace :masters do
  desc "Pull fellowships from osystem-masters and upsert into fellowships"
  task sync: :environment do
    result = MasterSync.run
    puts "synced #{result.count} fellowships (master updated_at=#{result.master_updated_at})"
  end
end
