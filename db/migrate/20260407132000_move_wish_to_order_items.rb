class MoveWishToOrderItems < ActiveRecord::Migration[8.0]
  def up
    add_column :order_items, :wish, :string unless column_exists?(:order_items, :wish)
    remove_column :orders, :wish, :text if column_exists?(:orders, :wish)
  end

  def down
    add_column :orders, :wish, :text unless column_exists?(:orders, :wish)
    remove_column :order_items, :wish, :string if column_exists?(:order_items, :wish)
  end
end
