class CreateProxyInventoryQuantities < ActiveRecord::Migration[8.1]
  class MigrationEvent < ApplicationRecord
    self.table_name = "events"
  end

  class MigrationProxyInventoryQuantity < ApplicationRecord
    self.table_name = "proxy_inventory_quantities"
  end

  def up
    create_table :proxy_inventory_quantities do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :item_index, null: false
      t.integer :quantity

      t.timestamps
    end

    add_index :proxy_inventory_quantities, [ :event_id, :item_index ], unique: true

    seed_31st_reference_quantities
  end

  def down
    drop_table :proxy_inventory_quantities
  end

  private

  def seed_31st_reference_quantities
    event = MigrationEvent.find_by(name: "第31回") || MigrationEvent.where(is_active: true).order(:id).last || MigrationEvent.order(:id).first
    return unless event

    { 0 => 7, 5 => 14 }.each do |item_index, quantity|
      MigrationProxyInventoryQuantity.find_or_create_by!(event_id: event.id, item_index: item_index) do |record|
        record.quantity = quantity
      end
    end
  end
end
