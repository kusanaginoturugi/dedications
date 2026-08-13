class EnsureDefaultEvent < ActiveRecord::Migration[8.1]
  class MigrationEvent < ApplicationRecord
    self.table_name = "events"
  end

  class MigrationOrder < ApplicationRecord
    self.table_name = "orders"
  end

  def up
    event = MigrationEvent.find_or_create_by!(name: "第31回") do |record|
      record.is_active = true
    end
    event.update!(is_active: true) unless event.is_active?

    MigrationOrder.where(event_id: nil).update_all(event_id: event.id)
  end

  def down
    # 履歴データの紐付けを壊さないため、戻し処理は行わない。
  end
end
