class CreatePreEventQuantities < ActiveRecord::Migration[8.1]
  def change
    create_table :pre_event_quantities do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :item_index, null: false
      t.integer :quantity, null: false, default: 0

      t.timestamps
    end

    add_index :pre_event_quantities, [ :event_id, :item_index ], unique: true
  end
end
