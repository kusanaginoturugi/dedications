class AddDedicationOnToOrders < ActiveRecord::Migration[8.0]
  class MigrationOrder < ApplicationRecord
    self.table_name = "orders"
  end

  def up
    add_column :orders, :dedication_on, :date

    MigrationOrder.reset_column_information
    MigrationOrder.find_each do |order|
      order.update_columns(dedication_on: order.created_at&.to_date || order.fax_received_on)
    end
  end

  def down
    remove_column :orders, :dedication_on
  end
end
