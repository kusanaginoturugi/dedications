require "test_helper"

class FellowshipTest < ActiveSupport::TestCase
  test "short name removes fellowship suffixes" do
    assert_equal "東京", Fellowship.new(name: "東京準総壇").short_name
    assert_equal "大阪中央", Fellowship.new(name: "大阪中央伝道会").short_name
    assert_equal "新潟", Fellowship.new(name: "新潟公壇").short_name
    assert_equal "新潟", Fellowship.new(name: "新潟準公壇").short_name
    assert_equal "北陸", Fellowship.new(name: "北陸準公壇").short_name
  end
end
