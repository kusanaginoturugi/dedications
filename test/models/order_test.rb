require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @existing_order = orders(:one) # wish_fulfillment_staff, range: 10..15
  end

  test "通し番号が重複していない場合は有効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: "wish_fulfillment_staff",
      page_number: 100,
      serial_number_start: 1,
      serial_number_end: 9
    )
    assert order.valid?

    order.serial_number_start = 16
    order.serial_number_end = 19
    assert order.valid?
  end

  test "同じ注文書種類で通し番号が完全に重複する場合は無効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: @existing_order.form_type,
      page_number: 100,
      serial_number_start: @existing_order.serial_number_start,
      serial_number_end: @existing_order.serial_number_end
    )
    assert_not order.valid?
    assert_includes order.errors[:base], "通し番号は同じ注文書種類ですでに使われています。"
  end

  test "同じ注文書種類で通し番号が一部重複（開始側）する場合は無効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: @existing_order.form_type,
      page_number: 100,
      serial_number_start: 5,
      serial_number_end: 10
    )
    assert_not order.valid?
  end

  test "同じ注文書種類で通し番号が一部重複（終了側）する場合は無効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: @existing_order.form_type,
      page_number: 100,
      serial_number_start: 15,
      serial_number_end: 20
    )
    assert_not order.valid?
  end

  test "同じ注文書種類で通し番号が既存の範囲を包含する場合は無効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: @existing_order.form_type,
      page_number: 100,
      serial_number_start: 5,
      serial_number_end: 20
    )
    assert_not order.valid?
  end

  test "異なる注文書種類であれば同じ通し番号でも有効であること" do
    order = Order.new(
      user: users(:admin),
      congregation: congregations(:tokyo),
      form_type: "sankai_ryuge_pillar",
      page_number: 100,
      serial_number_start: @existing_order.serial_number_start,
      serial_number_end: @existing_order.serial_number_end
    )
    assert order.valid?
  end

  test "自身の更新時には自身の通し番号は重複とみなされないこと" do
    assert @existing_order.valid?
    @existing_order.page_number = 999
    assert @existing_order.valid?
  end
end
