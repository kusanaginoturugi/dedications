require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name" do
    assert_equal "管理者", users(:admin).display_name
  end
end
