class CreateInventoryCheckQuantities < ActiveRecord::Migration[8.1]
  class MigrationEvent < ApplicationRecord
    self.table_name = "events"
  end

  class MigrationInventoryCheckQuantity < ApplicationRecord
    self.table_name = "inventory_check_quantities"
  end

  DEFAULT_VALUES = {
    0 => { "order_total" => 60, "proxy_quantity" => 7, "pre_event_quantity" => 53 },
    1 => { "order_total" => 130, "pre_event_quantity" => 69, "remaining_count" => 61 },
    2 => { "order_total" => 830, "proxy_quantity" => 482, "pre_event_quantity" => 318, "remaining_count" => 30 },
    3 => { "order_total" => 650, "proxy_quantity" => 595, "pre_event_quantity" => 40, "remaining_count" => 15 },
    4 => { "order_total" => 900, "proxy_quantity" => 647, "pre_event_quantity" => 253 },
    5 => { "stock_count" => 61, "proxy_quantity" => 15, "pre_event_quantity" => 43, "remaining_count" => 3 }
  }.freeze

  def up
    create_table :inventory_check_quantities do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :item_index, null: false
      t.string :field_name, null: false
      t.integer :quantity

      t.timestamps
    end

    add_index :inventory_check_quantities, [ :event_id, :item_index, :field_name ], unique: true

    seed_31st_reference_quantities
  end

  def down
    drop_table :inventory_check_quantities
  end

  private

  def seed_31st_reference_quantities
    event = MigrationEvent.find_by(name: "第31回") || MigrationEvent.where(is_active: true).order(:id).last || MigrationEvent.order(:id).first
    return unless event

    DEFAULT_VALUES.each do |item_index, fields|
      fields.each do |field_name, quantity|
        MigrationInventoryCheckQuantity.find_or_create_by!(event_id: event.id, item_index: item_index, field_name: field_name) do |record|
          record.quantity = quantity
        end
      end
    end
  end
end
