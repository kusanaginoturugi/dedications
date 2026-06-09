require "test_helper"
require "tempfile"

class FellowshipImporterTest < ActiveSupport::TestCase
  test "imports new fellowships from csv" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name
      99901,9901,札幌伝道会
    CSV

    assert_difference("Fellowship.count", 1) do
      assert_equal 1, FellowshipImporter.call(csv_path: csv_path)
    end

    fellowship = Fellowship.find_by!(code: "99901")
    assert_equal "9901", fellowship.old_code
    assert_equal "札幌伝道会", fellowship.name
  end

  test "updates existing fellowships with matching code" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name
      31301,1309,東京中央伝道会
    CSV

    assert_no_difference("Fellowship.count") do
      assert_equal 1, FellowshipImporter.call(csv_path: csv_path)
    end

    fellowship = fellowships(:tokyo).reload
    assert_equal "1309", fellowship.old_code
    assert_equal "東京中央伝道会", fellowship.name
  end

  test "skips blank rows" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name

      88801,8801,名古屋伝道会
    CSV

    assert_difference("Fellowship.count", 1) do
      assert_equal 1, FellowshipImporter.call(csv_path: csv_path)
    end
  end

  private

  def write_csv(contents)
    file = Tempfile.new([ "fellowships", ".csv" ])
    file.write(contents)
    file.flush
    file.path
  ensure
    file.close
  end
end
