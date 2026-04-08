class AddUniqueIndexToOrdersOnFormTypeAndPageNumber < ActiveRecord::Migration[8.0]
  def change
    add_index :orders, [ :form_type, :page_number ],
      unique: true,
      name: "index_orders_on_form_type_and_page_number"
  end
end
