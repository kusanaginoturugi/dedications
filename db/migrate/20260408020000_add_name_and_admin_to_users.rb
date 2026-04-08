class AddNameAndAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :is_admin, :boolean, null: false, default: false
  end
end
