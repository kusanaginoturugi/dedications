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

  test "shows only authentik sign in when configured" do
    with_authentik_env do
      get new_session_path

      assert_response :success
      assert_includes response.body, "Authentikでサインイン"
      assert_not_includes response.body, 'name="password"'
    end
  end

  test "rejects password sign in when authentik is configured" do
    with_authentik_env do
      post session_path, params: { email: users(:admin).email, password: "password123" }

      assert_redirected_to new_session_path
      get orders_path
      assert_redirected_to new_session_path
    end
  end

  test "redirects to authentik with state" do
    with_authentik_env do
      get authentik_login_path

      assert_response :redirect
      assert_match %r{\Ahttps://auth\.showway\.biz/application/o/authorize/\?}, response.location
      assert_includes response.location, "client_id=test-client"
      assert_includes response.location, "state="
    end
  end

  test "callback links existing user by email and syncs admin flag" do
    claims = { "sub" => "ak-operator", "email" => users(:operator).email, "name" => "一般利用者", "groups" => [ "dedications-admin" ] }

    sign_in_with_authentik(claims)

    assert_redirected_to orders_path
    user = users(:operator).reload
    assert_equal "ak-operator", user.authentik_subject
    assert user.is_admin?
  end

  test "callback creates a new non admin user" do
    claims = { "sub" => "ak-new", "email" => "New@Example.com", "name" => "新しい人", "groups" => [] }

    assert_difference "User.count", 1 do
      sign_in_with_authentik(claims)
    end

    user = User.find_by!(authentik_subject: "ak-new")
    assert_equal "new@example.com", user.email
    assert_not user.is_admin?
  end

  test "callback revokes admin when group is removed" do
    users(:admin).update!(authentik_subject: "ak-admin")

    sign_in_with_authentik({ "sub" => "ak-admin", "email" => users(:admin).email, "groups" => [] })

    assert_not users(:admin).reload.is_admin?
  end

  test "callback rejects mismatched state" do
    with_authentik_env do
      get authentik_login_path
      get authentik_callback_path, params: { state: "wrong", code: "code" }

      assert_redirected_to new_session_path
      get orders_path
      assert_redirected_to new_session_path
    end
  end

  private

  def with_authentik_env
    original = ENV.to_h.slice("AUTHENTIK_CLIENT_ID", "AUTHENTIK_CLIENT_SECRET")
    ENV["AUTHENTIK_CLIENT_ID"] = "test-client"
    ENV["AUTHENTIK_CLIENT_SECRET"] = "test-secret"
    yield
  ensure
    %w[AUTHENTIK_CLIENT_ID AUTHENTIK_CLIENT_SECRET].each { |key| ENV[key] = original[key] }
  end

  def sign_in_with_authentik(claims)
    with_authentik_env do
      with_authentik_responses(claims) do
        get authentik_login_path
        state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
        get authentik_callback_path, params: { state: state, code: "code" }
      end
    end
  end

  def with_authentik_responses(claims)
    singleton = AuthentikClient.singleton_class
    originals = { exchange_code: AuthentikClient.method(:exchange_code), userinfo: AuthentikClient.method(:userinfo) }
    singleton.define_method(:exchange_code) { |_code| "access-token" }
    singleton.define_method(:userinfo) { |_token| claims }
    yield
  ensure
    originals.each { |name, method| singleton.define_method(name, method) }
  end
end
