require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get orders_path

    assert_redirected_to new_session_path
  end

  test "lists orders for signed in user" do
    sign_in_as(users(:admin))

    get orders_path

    assert_response :success
    assert_includes response.body, orders(:one).form_label
  end

  test "creates an order" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", 1) do
      assert_difference("OrderItem.count", 1) do
        post orders_path, params: {
          order: {
            page_number: 2,
            form_type: "wish_fulfillment_staff",
            paid: "1",
            congregation_id: congregations(:osaka).id,
            contact_name: "鈴木一郎",
            phone: "06-1111-2222",
            order_items_attributes: [
              { entry_number: "A-1", donor_name: "佐藤次郎", wish: "商売繁盛", quantity: 3, amount: 6000, position: 0 },
              { entry_number: "", donor_name: "", quantity: "", amount: "", position: 1 }
            ]
          }
        }
      end
    end

    assert_redirected_to order_path(Order.order(:created_at).last)
  end
end
