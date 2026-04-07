class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.string :entry_number
      t.string :donor_name
      t.integer :quantity, null: false, default: 0
      t.integer :amount, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :order_items, [ :order_id, :position ], unique: true
  end
end
