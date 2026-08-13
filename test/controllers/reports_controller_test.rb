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
    assert_includes response.body, "天地免劫護摩木"
    assert_not_includes response.body, "天地免劫&lt;br&gt;護摩木"
    assert_select "form#pre-event-report-form[method='post'][action='#{save_pre_event_reports_path}']"
    assert_select "form#pre-event-report-form button.primary-button", text: "保存"
    assert_select "button[form='pre-event-report-form']", count: 0
    assert_select "[data-total-quantity]", count: 0
    assert_select "[data-total-miroku]", count: 1
  end

  test "saves pre event quantities for the current event" do
    sign_in_as(users(:admin))

    post save_pre_event_reports_path, params: {
      quantities: {
        "0" => "3",
        "7" => "12"
      }
    }

    assert_redirected_to pre_event_reports_path
    assert_equal 3, events(:one).pre_event_quantities.find_by!(item_index: 0).quantity
    assert_equal 12, events(:one).pre_event_quantities.find_by!(item_index: 7).quantity

    get pre_event_reports_path

    assert_response :success
    assert_select "input[name='quantities[0]'][value='3']"
    assert_select "input[name='quantities[7]'][value='12']"
  end

  test "does not overwrite pre event quantities when no quantities are posted" do
    sign_in_as(users(:admin))
    events(:one).pre_event_quantities.create!(item_index: 0, quantity: 9)

    post save_pre_event_reports_path

    assert_redirected_to pre_event_reports_path
    assert_equal 9, events(:one).pre_event_quantities.find_by!(item_index: 0).quantity
  end

  test "does not report save success without a current event" do
    sign_in_as(users(:admin))
    PreEventQuantity.delete_all
    Order.update_all(event_id: nil)
    Event.delete_all

    post save_pre_event_reports_path, params: { quantities: { "0" => "3" } }

    assert_redirected_to pre_event_reports_path
    follow_redirect!
    assert_includes response.body, "保存先の回次がありません。管理者に確認してください。"
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
    assert_includes response.body, "表② 代理奉納（地方代理＝護摩センター振込分）"
    assert_includes response.body, "明王如意棒"
    assert_includes response.body, "道具数チェック"
    assert_includes response.body, "報告担当者：尾ノ上裕美"
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
    assert_select "th", text: "入金済み", count: 2
    assert_select "th", text: "未入金", count: 2
    assert_select "th", text: "入金済み本数", count: 0
    assert_select "th", text: "未入金本数", count: 0
    assert_not_includes response.body, "伝道会ごとの入金済み本数、未入金本数、合計本数を表示します。"
  end

  test "typed dedication counts include special fellowships" do
    sign_in_as(users(:admin))

    [
      [ "90000", "弥勒寺", 900, 1000, 1001 ],
      [ "10000", "聖治命院", 901, 1010, 1012 ],
      [ "90001", "加賀御神水", 902, 1020, 1023 ],
      [ "10001", "聖龍華院", 903, 1030, 1034 ]
    ].each do |code, name, page_number, serial_start, serial_end|
      fellowship = Fellowship.find_or_create_by!(code:) do |record|
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
        fellowship: fellowship,
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

    fellowship = Fellowship.create!(code: "10121", old_code: "0121", name: "江別昇龍壇")
    Order.create!(
      page_number: 99,
      fax_received_on: Date.current,
      dedication_on: Date.current,
      form_type: "wish_fulfillment_staff",
      offerer_name: "PDF確認",
      paid: true,
      fellowship: fellowship,
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
