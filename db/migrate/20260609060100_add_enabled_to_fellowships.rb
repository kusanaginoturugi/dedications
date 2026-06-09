# frozen_string_literal: true

class AddEnabledToFellowships < ActiveRecord::Migration[8.1]
  def up
    add_column :fellowships, :enabled, :boolean, null: false, default: false
    execute "UPDATE fellowships SET enabled = 1"
  end

  def down
    remove_column :fellowships, :enabled
  end
end
