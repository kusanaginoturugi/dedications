class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.integer :page_number, null: false
      t.string :form_type, null: false
      t.boolean :paid, null: false, default: false
      t.string :contact_name
      t.string :phone
      t.text :wish
      t.references :user, null: false, foreign_key: true
      t.references :congregation, null: false, foreign_key: true

      t.timestamps
    end

    add_index :orders, [ :congregation_id, :page_number ]
  end
end
