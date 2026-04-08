require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get users_path

    assert_redirected_to new_session_path
  end

  test "rejects non admin user" do
    sign_in_as(users(:operator))

    get users_path

    assert_redirected_to orders_path
  end

  test "lists users for admin" do
    sign_in_as(users(:admin))

    get users_path

    assert_response :success
    assert_includes response.body, users(:operator).email
  end

  test "shows new user form for admin" do
    sign_in_as(users(:admin))

    get new_user_path

    assert_response :success
    assert_includes response.body, "ユーザー追加"
  end

  test "creates user for admin" do
    sign_in_as(users(:admin))

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          name: "新規担当者",
          email: "new-user@example.com",
          is_admin: "0",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to users_path
    assert_equal "新規担当者", User.order(:created_at).last.name
  end

  test "updates user for admin" do
    sign_in_as(users(:admin))

    patch user_path(users(:operator)), params: {
      user: {
        name: "担当者A",
        email: "operator@example.com",
        is_admin: "1"
      }
    }

    assert_redirected_to users_path
    users(:operator).reload
    assert_equal "担当者A", users(:operator).name
    assert_predicate users(:operator), :is_admin?
  end
end
