require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "shows the sign in page" do
    get new_session_path

    assert_response :success
  end

  test "signs in with valid credentials" do
    post session_path, params: { email: users(:admin).email, password: "password123" }

    assert_redirected_to orders_path
  end
end
