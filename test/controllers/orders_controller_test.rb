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

  test "shows order summary" do
    sign_in_as(users(:admin))

    get summary_orders_path

    assert_response :success
    assert_includes response.body, "注文集計"
    assert_includes response.body, orders(:one).form_label
  end

  test "shows personal summary" do
    sign_in_as(users(:admin))

    get personal_summary_orders_path

    assert_response :success
    assert_includes response.body, "個別集計"
    assert_includes response.body, users(:admin).display_name
  end

  test "creates an order" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", 1) do
      post orders_path, params: {
        order: {
          page_number: 2,
          fax_received_on: "2026-04-08",
          form_type: "wish_fulfillment_staff",
          paid: "1",
          congregation_id: congregations(:osaka).id,
          serial_number_start: 100,
          serial_number_end: 125
        }
      }
    end

    assert_redirected_to order_path(Order.order(:created_at).last)
  end

  test "shows edit form" do
    sign_in_as(users(:admin))

    get edit_order_path(orders(:one))

    assert_response :success
    assert_includes response.body, "注文編集"
  end

  test "updates an order" do
    sign_in_as(users(:admin))

    patch order_path(orders(:one)), params: {
      order: {
        page_number: 9,
        fax_received_on: "2026-04-09",
        form_type: "sanki_reiboku",
        paid: "1",
        congregation_id: congregations(:osaka).id,
        serial_number_start: 200,
        serial_number_end: 240
      }
    }

    assert_redirected_to orders_path
    orders(:one).reload
    assert_equal 9, orders(:one).page_number
    assert_equal 200, orders(:one).serial_number_start
  end
end
