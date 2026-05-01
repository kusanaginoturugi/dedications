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
    assert_includes response.body, orders(:one).offerer_name
  end

  test "new order defaults fax received on to today" do
    sign_in_as(users(:admin))

    get new_order_path

    assert_response :success
    assert_includes response.body, "value=\"#{Date.current}\""
  end

  test "sorts orders by page ascending" do
    sign_in_as(users(:admin))

    get orders_path, params: { sort: "page_number", direction: "asc" }

    assert_response :success
    assert_operator response.body.index(">1<"), :<, response.body.index(">15<")
  end

  test "redirects order summary to order list" do
    sign_in_as(users(:admin))

    get summary_orders_path

    assert_redirected_to orders_path
  end

  test "order list includes unified columns" do
    sign_in_as(users(:admin))

    get orders_path

    assert_response :success
    %w[番号 奉納者名 FAX受信日 奉納日 種類 通し番号 本数 金額 入金状態 入力日].each do |heading|
      assert_includes response.body, heading
    end
  end

  test "order list groups orders by requested form type order" do
    sign_in_as(users(:admin))

    Order.create!(
      page_number: 30,
      fax_received_on: "2026-04-10",
      dedication_on: "2026-04-10",
      form_type: "sanki_reiboku",
      offerer_name: "三期テスト",
      paid: true,
      serial_number_start: 100,
      serial_number_end: 101,
      user: users(:admin),
      congregation: congregations(:tokyo),
      event: events(:one)
    )
    Order.create!(
      page_number: 31,
      fax_received_on: "2026-04-11",
      dedication_on: "2026-04-11",
      form_type: "sankai_ryuge_pillar",
      offerer_name: "三會テスト",
      paid: false,
      serial_number_start: 200,
      serial_number_end: 201,
      user: users(:admin),
      congregation: congregations(:tokyo),
      event: events(:one)
    )

    get orders_path

    assert_response :success
    assert_operator response.body.index("八大明王如意棒"), :<, response.body.index("三期滅劫\n之霊木")
    assert_operator response.body.index("三期滅劫\n之霊木"), :<, response.body.index("三會龍華\n之御柱")
  end

  test "shows personal summary" do
    sign_in_as(users(:admin))

    get personal_summary_orders_path

    assert_response :success
    assert_includes response.body, "個別集計"
    assert_includes response.body, users(:admin).display_name
  end

  test "sorts personal summary by page ascending" do
    sign_in_as(users(:admin))

    get personal_summary_orders_path, params: { sort: "page_number", direction: "asc" }

    assert_response :success
    assert_operator response.body.index(">1<"), :<, response.body.index(">15<")
  end

  test "creates an order" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", 1) do
      post orders_path, params: {
        order: {
          page_number: 2,
          fax_received_on: "2026-04-08",
          form_type: "wish_fulfillment_staff",
          offerer_name: "高橋美咲",
          paid: "1",
          congregation_id: congregations(:osaka).id,
          serial_number_start: 100,
          serial_number_end: 125
        }
      }
    end

    created_order = Order.order(:created_at).last
    assert_redirected_to order_path(created_order)
    assert_equal "高橋美咲", created_order.offerer_name
  end

  test "creates an order by congregation name query" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", 1) do
      post orders_path, params: {
        order: {
          page_number: 3,
          fax_received_on: "2026-04-08",
          dedication_on: "2026-04-08",
          form_type: "sankai_ryuge_pillar",
          offerer_name: "名前検索",
          paid: "1",
          congregation_id: "",
          congregation_query: "泉珠",
          serial_number_start: 300,
          serial_number_end: 305
        }
      }
    end

    created_order = Order.order(:created_at).last
    assert_redirected_to order_path(created_order)
    assert_equal congregations(:senzu), created_order.congregation
  end

  test "shows edit form" do
    sign_in_as(users(:admin))

    get edit_order_path(orders(:one))

    assert_response :success
    assert_includes response.body, "申込編集"
    assert_includes response.body, "削除"
    assert_includes response.body, "八大明王如意棒"
    assert_includes response.body, "三會龍華之御柱"
    assert_includes response.body, "三期滅劫之霊木"
    assert_not_includes response.body, "<select"
    assert_equal 2, response.body.scan(/<form[^>]+action="\/orders\/#{orders(:one).id}"/).size
    assert_includes response.body, %(class="delete-order-form")
  end

  test "shows form type choices on new order without dropdown" do
    sign_in_as(users(:admin))

    get new_order_path

    assert_response :success
    assert_includes response.body, "八大明王如意棒"
    assert_includes response.body, "三會龍華之御柱"
    assert_includes response.body, "三期滅劫之霊木"
    assert_not_includes response.body, "<select"
  end

  test "rejects duplicate page number within same form type on create" do
    sign_in_as(users(:admin))

    assert_no_difference("Order.count") do
      post orders_path, params: {
        order: {
          page_number: orders(:one).page_number,
          fax_received_on: "2026-04-10",
          form_type: orders(:one).form_type,
          paid: "0",
          congregation_id: congregations(:osaka).id,
          serial_number_start: 30,
          serial_number_end: 32
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "ページ番号は同じ申込書種類ですでに使われています"
  end

  test "shows missing congregation error in Japanese" do
    sign_in_as(users(:admin))

    post orders_path, params: {
      order: {
        page_number: 88,
        fax_received_on: "2026-04-10",
        dedication_on: "2026-04-10",
        form_type: "wish_fulfillment_staff",
        paid: "0",
        congregation_id: "",
        serial_number_start: 30,
        serial_number_end: 32
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "伝道会を選択してください"
    assert_not_includes response.body, "Translation missing"
  end

  test "allows same page number for different form type" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", 1) do
      post orders_path, params: {
        order: {
          page_number: orders(:one).page_number,
          fax_received_on: "2026-04-10",
          form_type: "sanki_reiboku",
          paid: "0",
          congregation_id: congregations(:osaka).id,
          serial_number_start: 30,
          serial_number_end: 32
        }
      }
    end
  end

  test "updates an order" do
    sign_in_as(users(:admin))

    patch order_path(orders(:one)), params: {
      order: {
        page_number: 9,
        fax_received_on: "2026-04-09",
        form_type: "sanki_reiboku",
        offerer_name: "伊藤美紀",
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
    assert_equal "伊藤美紀", orders(:one).offerer_name
  end

  test "keeps existing values when edit submits blank fields" do
    sign_in_as(users(:admin))
    order = orders(:one)
    original_attributes = order.attributes.slice(
      "page_number",
      "fax_received_on",
      "form_type",
      "offerer_name",
      "congregation_id",
      "serial_number_start",
      "serial_number_end"
    )

    patch order_path(order), params: {
      order: {
        page_number: "",
        fax_received_on: "",
        dedication_on: "",
        form_type: "",
        offerer_name: "",
        paid: order.paid ? "1" : "0",
        congregation_id: "",
        serial_number_start: "",
        serial_number_end: ""
      }
    }

    assert_redirected_to orders_path
    order.reload
    original_attributes.each do |attribute, value|
      assert_equal value, order.public_send(attribute)
    end
  end

  test "rejects duplicate page number within same form type on update" do
    sign_in_as(users(:admin))

    patch order_path(orders(:one)), params: {
      order: {
        page_number: orders(:two).page_number,
        fax_received_on: orders(:one).fax_received_on,
        form_type: orders(:one).form_type,
        paid: orders(:one).paid,
        congregation_id: orders(:one).congregation_id,
        serial_number_start: orders(:one).serial_number_start,
        serial_number_end: orders(:one).serial_number_end
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "ページ番号は同じ申込書種類ですでに使われています"
  end

  test "destroys an order" do
    sign_in_as(users(:admin))

    assert_difference("Order.count", -1) do
      delete order_path(orders(:one))
    end

    assert_redirected_to orders_path
  end
end
