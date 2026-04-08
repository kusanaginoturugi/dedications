class ReplaceContactFieldsWithFaxMetadata < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :fax_received_on, :date
    add_column :orders, :serial_number_start, :integer
    add_column :orders, :serial_number_end, :integer

    remove_column :orders, :contact_name, :string
    remove_column :orders, :phone, :string
  end
end
