require "test_helper"

class CongregationsControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get congregations_path(query: "31"), as: :json

    assert_redirected_to new_session_path
  end

  test "returns filtered congregations" do
    sign_in_as(users(:admin))

    get congregations_path(query: "31"), as: :json

    assert_response :success
    assert_includes response.parsed_body.first.fetch("code"), "31"
  end

  test "returns congregations filtered by name" do
    sign_in_as(users(:admin))

    get congregations_path(query: "泉珠"), as: :json

    assert_response :success
    assert_equal "42407", response.parsed_body.first.fetch("code")
    assert_equal "泉珠準総壇", response.parsed_body.first.fetch("name")
  end
end
