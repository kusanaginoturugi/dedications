require "test_helper"
require "tempfile"

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

  test "downloads pre event csv and pdf" do
    sign_in_as(users(:admin))

    get pre_event_reports_path(format: :csv, quantities: { "0" => "3" })

    assert_response :success
    assert_equal "text/csv", response.media_type

    get pre_event_reports_path(format: :pdf, quantities: { "0" => "3" })

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_match(/\A%PDF/, response.body)
  end

  test "shows proxy inventory report" do
    sign_in_as(users(:admin))

    get proxy_inventory_reports_path

    assert_response :success
    assert_includes response.body, "帳票: 代理・在庫"
    assert_includes response.body, "明王如意棒"
  end

  test "downloads proxy inventory csv and pdf" do
    sign_in_as(users(:admin))

    get proxy_inventory_reports_path(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type

    get proxy_inventory_reports_path(format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_match(/\A%PDF/, response.body)
  end

  test "shows dedication counts report" do
    sign_in_as(users(:admin))

    get dedication_counts_reports_path

    assert_response :success
    assert_includes response.body, "帳票: 各種代理奉納"
    assert_includes response.body, "新潟公壇"
  end

  test "shows typed dedication counts report" do
    sign_in_as(users(:admin))

    get dedication_counts_by_type_reports_path(form_type: "wish_fulfillment_staff")

    assert_response :success
    assert_includes response.body, "帳票: 八大明王如意棒"
    assert_not_includes response.body, "伝道会ごとの入金済み本数、未入金本数、合計本数を表示します。"
  end

  test "typed dedication counts include special congregations" do
    sign_in_as(users(:admin))

    [
      [ "90000", "弥勒寺", 900, 1000, 1001 ],
      [ "10000", "聖治命院", 901, 1010, 1012 ],
      [ "90001", "加賀御神水", 902, 1020, 1023 ],
      [ "10001", "聖龍華院", 903, 1030, 1034 ]
    ].each do |code, name, page_number, serial_start, serial_end|
      congregation = Congregation.find_or_create_by!(code:) do |record|
        record.old_code = code
        record.name = name
      end
      Order.create!(
        page_number: page_number,
        fax_received_on: Date.current,
        dedication_on: Date.current,
        form_type: "wish_fulfillment_staff",
        offerer_name: name,
        paid: true,
        congregation: congregation,
        user: users(:admin),
        event: events(:one),
        serial_number_start: serial_start,
        serial_number_end: serial_end
      )
    end

    get dedication_counts_by_type_reports_path(form_type: "wish_fulfillment_staff")

    assert_response :success
    assert_select "tr", text: /弥勒寺.*2 本/
    assert_select "tr", text: /聖治命院\(モンゴル\).*3 本/
    assert_select "tr", text: /\(株\)加賀御神水.*4 本/
    assert_select "tr", text: /聖龍華院.*5 本/
    assert_select "tr.total-row", text: /合計.*14 本/
    rows = css_select(".counts-sheet-grid section:last-child tbody tr")
    seiryugein_index = rows.index { |row| row.text.include?("聖龍華院") }
    total_index = rows.index { |row| row.text.include?("合計") }

    assert seiryugein_index, "聖龍華院の行が見つかること"
    assert_equal seiryugein_index + 2, total_index
    assert_includes rows[seiryugein_index + 1]["class"].to_s, "blank-row"
  end

  test "typed dedication counts leave a blank row between niigata and hokuriku" do
    sign_in_as(users(:admin))

    get dedication_counts_by_type_reports_path(form_type: "wish_fulfillment_staff")

    assert_response :success
    rows = css_select(".counts-sheet-grid section:first-child tbody tr")
    niigata_index = rows.index { |row| row.text.include?("新潟公壇") }
    hokuriku_index = rows.index { |row| row.text.include?("北陸公壇") }

    assert niigata_index, "新潟公壇の行が見つかること"
    assert_equal niigata_index + 2, hokuriku_index
    assert_includes rows[niigata_index + 1]["class"].to_s, "blank-row"
  end

  test "downloads dedication counts pdf without browser print mode" do
    sign_in_as(users(:admin))

    congregation = Congregation.create!(code: "10121", old_code: "0121", name: "江別昇龍壇")
    Order.create!(
      page_number: 99,
      fax_received_on: Date.current,
      dedication_on: Date.current,
      form_type: "wish_fulfillment_staff",
      offerer_name: "PDF確認",
      paid: true,
      congregation: congregation,
      user: users(:admin),
      event: events(:one),
      serial_number_start: 300,
      serial_number_end: 306
    )

    get dedication_counts_by_type_reports_path(form_type: "wish_fulfillment_staff", format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_match(/\A%PDF/, response.body)
    assert_pdf_text_includes response.body, "帳票: 八大明王如意棒"
    assert_pdf_text_includes response.body, "江別昇龍壇"
  end

  private

  def assert_pdf_text_includes(pdf_body, expected_text)
    skip "pdftotext is not installed" unless system("which", "pdftotext", out: File::NULL)

    Tempfile.create([ "dedication-counts", ".pdf" ]) do |pdf|
      pdf.binmode
      pdf.write(pdf_body)
      pdf.flush

      text = IO.popen([ "pdftotext", pdf.path, "-" ], &:read)
      assert_includes text, expected_text
    end
  end
end
