class AddEventIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :event, foreign_key: true
  end
end
