class CreateCongregations < ActiveRecord::Migration[8.0]
  def change
    create_table :congregations do |t|
      t.string :code, null: false
      t.string :old_code
      t.string :name, null: false

      t.timestamps
    end

    add_index :congregations, :code, unique: true
  end
end
