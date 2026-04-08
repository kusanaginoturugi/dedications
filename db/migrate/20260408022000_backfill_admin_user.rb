class BackfillAdminUser < ActiveRecord::Migration[8.0]
  class User < ApplicationRecord
    self.table_name = "users"
  end

  def up
    admin = User.find_by(email: "admin@example.com")
    return unless admin

    admin.update_columns(is_admin: true) unless admin.is_admin?
    admin.update_columns(name: "管理者") if admin.name.blank? || admin.name == "admin"
  end

  def down
  end
end
