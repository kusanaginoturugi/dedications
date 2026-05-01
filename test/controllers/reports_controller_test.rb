require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get pre_event_reports_path

    assert_redirected_to new_session_path
  end

  test "shows pre event report" do
    sign_in_as(users(:admin))

    get pre_event_reports_path

    assert_response :success
    assert_includes response.body, "帳票: 前夜祭・当日"
  end

  test "shows proxy inventory report" do
    sign_in_as(users(:admin))

    get proxy_inventory_reports_path

    assert_response :success
    assert_includes response.body, "帳票: 代理・在庫"
    assert_includes response.body, "明王如意棒"
  end

  test "shows dedication counts report" do
    sign_in_as(users(:admin))

    get dedication_counts_reports_path

    assert_response :success
    assert_includes response.body, "帳票: 各種代理奉納"
    assert_includes response.body, "新潟公壇"
  end

  test "downloads dedication counts pdf without browser print mode" do
    sign_in_as(users(:admin))

    congregation = Congregation.create!(code: "10121", old_code: "0121", name: "江別昇龍壇")
    Order.create!(
      page_number: 99,
      fax_received_on: Date.current,
      dedication_on: Date.current,
      form_type: "wish_fulfillment_staff",
      offerer_name: "PDF確認",
      paid: true,
      congregation: congregation,
      user: users(:admin),
      event: events(:one),
      serial_number_start: 300,
      serial_number_end: 306
    )

    get dedication_counts_by_type_reports_path(form_type: "wish_fulfillment_staff", format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_match(/\A%PDF/, response.body)
  end
end
