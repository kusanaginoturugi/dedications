# frozen_string_literal: true

class RenameCongregationsToFellowships < ActiveRecord::Migration[8.1]
  def change
    rename_table :congregations, :fellowships
    rename_column :orders, :congregation_id, :fellowship_id
  end
end
