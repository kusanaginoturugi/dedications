require "test_helper"

class CongregationTest < ActiveSupport::TestCase
  test "short name removes congregation suffixes" do
    assert_equal "東京", Congregation.new(name: "東京準総壇").short_name
    assert_equal "大阪中央", Congregation.new(name: "大阪中央伝道会").short_name
    assert_equal "新潟", Congregation.new(name: "新潟公壇").short_name
  end
end
