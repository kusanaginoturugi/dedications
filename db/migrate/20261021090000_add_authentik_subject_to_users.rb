class AddAuthentikSubjectToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :authentik_subject, :string
    add_index :users, :authentik_subject, unique: true
  end
end
