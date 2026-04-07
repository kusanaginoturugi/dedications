class UpdateOrdersAndOrderItemsForFaxEntry < ActiveRecord::Migration[8.0]
  def up
    remove_column :orders, :donor_name, :string if column_exists?(:orders, :donor_name)

    if index_exists?(:order_items, [ :order_id, :item_code ], name: "index_order_items_on_order_id_and_item_code")
      remove_index :order_items, name: "index_order_items_on_order_id_and_item_code"
    end

    rename_column :order_items, :item_code, :entry_number if column_exists?(:order_items, :item_code)
    rename_column :order_items, :item_name, :donor_name if column_exists?(:order_items, :item_name)

    change_column_null :order_items, :entry_number, true if column_exists?(:order_items, :entry_number)
    change_column_null :order_items, :donor_name, true if column_exists?(:order_items, :donor_name)

    add_index :order_items, [ :order_id, :position ], unique: true unless index_exists?(:order_items, [ :order_id, :position ])
  end

  def down
    remove_index :order_items, column: [ :order_id, :position ] if index_exists?(:order_items, [ :order_id, :position ])

    rename_column :order_items, :entry_number, :item_code if column_exists?(:order_items, :entry_number)
    rename_column :order_items, :donor_name, :item_name if column_exists?(:order_items, :donor_name)

    change_column_null :order_items, :item_code, false if column_exists?(:order_items, :item_code)
    change_column_null :order_items, :item_name, false if column_exists?(:order_items, :item_name)

    add_index :order_items, [ :order_id, :item_code ], unique: true unless index_exists?(:order_items, [ :order_id, :item_code ])

    add_column :orders, :donor_name, :string unless column_exists?(:orders, :donor_name)
  end
end
