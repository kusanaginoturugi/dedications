class RelaxEventRequirementOnOrders < ActiveRecord::Migration[8.0]
  def change
    change_column_null :orders, :event_id, true
  end
end
