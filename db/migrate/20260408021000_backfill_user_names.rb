class BackfillUserNames < ActiveRecord::Migration[8.0]
  class User < ApplicationRecord
    self.table_name = "users"
  end

  def up
    User.where(name: [ nil, "" ]).find_each do |user|
      user.update_columns(name: inferred_name_for(user))
    end
  end

  def down
  end

  private

  def inferred_name_for(user)
    return "管理者" if user.is_admin?

    user.email.to_s.split("@").first.presence || "担当者"
  end
end
