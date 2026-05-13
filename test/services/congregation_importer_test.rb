require "test_helper"
require "tempfile"

class CongregationImporterTest < ActiveSupport::TestCase
  test "imports new congregations from csv" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name
      99901,9901,札幌伝道会
    CSV

    assert_difference("Congregation.count", 1) do
      assert_equal 1, CongregationImporter.call(csv_path: csv_path)
    end

    congregation = Congregation.find_by!(code: "99901")
    assert_equal "9901", congregation.old_code
    assert_equal "札幌伝道会", congregation.name
  end

  test "updates existing congregations with matching code" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name
      31301,1309,東京中央伝道会
    CSV

    assert_no_difference("Congregation.count") do
      assert_equal 1, CongregationImporter.call(csv_path: csv_path)
    end

    congregation = congregations(:tokyo).reload
    assert_equal "1309", congregation.old_code
    assert_equal "東京中央伝道会", congregation.name
  end

  test "skips blank rows" do
    csv_path = write_csv(<<~CSV)
      code,old_code,name

      88801,8801,名古屋伝道会
    CSV

    assert_difference("Congregation.count", 1) do
      assert_equal 1, CongregationImporter.call(csv_path: csv_path)
    end
  end

  private

  def write_csv(contents)
    file = Tempfile.new([ "congregations", ".csv" ])
    file.write(contents)
    file.flush
    file.path
  ensure
    file.close
  end
end
