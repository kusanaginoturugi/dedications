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
    assert_includes response.body, congregations(:tokyo).name
  end
end
