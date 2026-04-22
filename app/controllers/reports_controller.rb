require "csv"

class ReportsController < ApplicationController
  PRE_EVENT_ITEMS = [
    { label: "弥勒収円\n大護摩板", plain_label: "弥勒収円大護摩板", unit_price: 4000, refund_unit: 2000, miroku_unit: 2000 },
    { label: "各種平定\n之御柱", plain_label: "各種平定之御柱", unit_price: 2000, refund_unit: 300, miroku_unit: 1700 },
    { label: "三期滅劫\n之霊木", plain_label: "三期滅劫之霊木", unit_price: 800, refund_unit: 100, miroku_unit: 700 },
    { label: "三會龍華\n之御柱", plain_label: "三會龍華之御柱", unit_price: 500, refund_unit: 150, miroku_unit: 350 },
    { label: "その他のハッピーポール", plain_label: "その他のハッピーポール", unit_price: 500, refund_unit: 150, miroku_unit: 350 },
    { label: "灶君護摩木・収天護摩木", plain_label: "灶君護摩木・収天護摩木", unit_price: 200, refund_unit: 60, miroku_unit: 140 },
    { label: "地護摩木", plain_label: "地護摩木", unit_price: 100, refund_unit: 50, miroku_unit: 50 },
    { label: "天地免劫<br>護摩木", plain_label: "天地免劫護摩木", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "原佛子結集の護摩木", plain_label: "原佛子結集の護摩木", unit_price: 40, refund_unit: 0, miroku_unit: 40 },
    { label: "おかげ符", plain_label: "おかげ符", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "仙丹茶\n（禄存五聖杯）", plain_label: "仙丹茶（禄存五聖杯）", unit_price: 300, refund_unit: 0, miroku_unit: 300 },
    { label: "特別祈祷", plain_label: "特別祈祷", unit_price: 5000, refund_unit: 1000, miroku_unit: 4000 },
    { label: "明王如意棒", plain_label: "明王如意棒", unit_price: 2000, refund_unit: 800, miroku_unit: 1200 },
    { label: "八大明王札", plain_label: "八大明王札", unit_price: 600, refund_unit: 600, miroku_unit: 0 },
    { label: "幟", plain_label: "幟", unit_price: 3000, refund_unit: 0, miroku_unit: 3000 },
    { label: "泉珠卜占", plain_label: "泉珠卜占", unit_price: 500, refund_unit: 200, miroku_unit: 300 }
  ].freeze

  before_action :require_sign_in!

  def pre_event
    @rows = PRE_EVENT_ITEMS.map do |item|
      item.merge(quantity: 0, sales: 0, seiin_amount: 0, miroku_amount: 0)
    end
  end

  def proxy_inventory
    @rows = Order::FORM_DEFINITIONS.map do |form_type, definition|
      quantity = current_event.orders.where(form_type:).sum { |order| order.total_quantity.to_i }
      {
        label: definition.fetch(:report_label),
        unit_price: definition.fetch(:unit_price),
        quantity:,
        sales: quantity * definition.fetch(:unit_price),
        refund_unit: definition.fetch(:refund_unit),
        seiin_amount: quantity * definition.fetch(:refund_unit),
        miroku_unit: definition.fetch(:miroku_unit),
        miroku_amount: quantity * definition.fetch(:miroku_unit)
      }
    end
    @proxy_totals = {
      quantity: @rows.sum { |row| row[:quantity] },
      sales: @rows.sum { |row| row[:sales] },
      seiin_amount: @rows.sum { |row| row[:seiin_amount] },
      miroku_amount: @rows.sum { |row| row[:miroku_amount] }
    }
  end

  def dedication_counts
    @form_type = params[:form_type]
    if @form_type.present?
      @form_label = Order.form_definition_for(@form_type).fetch(:label)
    end

    # 左列の定義
    left_codes = [
      "10121", "10122", "10131", "10141",
      :blank,
      "20201", "20301", "20401", "20501", "20603", "20605", "20606", "20701",
      :blank,
      "31101", "31201", "31305", "31304", "31303", "31407", "32204", "32205", "31901",
      :blank,
      "92001", "41505", "41605", "42153", "42154", "42152", "42110", "42111", "42303", "42304", "42305", "42403", "42404", "42411", "42410", "42407", "42408"
    ]

    # 右列の定義
    right_codes = [
      "52501", "52601", "52703", "52702", "52801", "52802", "52901",
      :blank,
      "63101", "63201", "63302", "63401", "63501", "63601", "63602", "63702", "63703", "63801", "63804", "63803", "63901", "63902",
      :blank,
      "74001", "74101", "74201", "74310", "74502", "74504", "74503", "74605", "74606",
      :blank,
      "84702", "84703",
      :blank,
      "9000", "99000", "99001" # 弥勒寺, 聖治命院, 加賀御神水 (仮のコード)
    ]

    # 名称変更の定義
    name_overrides = {
      "41505" => "新潟公壇",
      "41605" => "北陸公壇",
      "63302" => "岡山北大楽<br>伝道会",
      "9000" => "弥勒寺",
      "99000" => "聖治命院(モンゴル)",
      "99001" => "(株)加賀御神水"
    }

    # データを組み立てる補助メソッド
    build_row = ->(code) {
      if code == :blank
        return { is_blank: true }
      end

      congregation = Congregation.find_by(code: code)
      # データベースにない場合も、名称変更があれば特別枠として扱う（弥勒寺など）
      if !congregation && name_overrides.key?(code)
        congregation = Congregation.new(code: code, name: name_overrides[code])
      end

      return nil unless congregation

      orders = current_event.orders.where(congregation: congregation)
      orders = orders.where(form_type: @form_type) if @form_type.present?

      {
        is_blank: false,
        code: congregation.code,
        name: name_overrides[congregation.code] || congregation.name,
        paid_count: paid_count,
        unpaid_count: unpaid_count,
        total_count: paid_count + unpaid_count
      }
    }

    @left_rows = left_codes.map { |c| build_row.call(c) }.compact
    @right_rows = right_codes.map { |c| build_row.call(c) }.compact

    respond_to do |format|
      format.html
      format.csv do
        filename = "#{@form_label || '各種代理奉納合計'}_#{Date.current.strftime('%Y%m%d')}.csv"
        send_data generate_dedication_counts_csv, filename: filename, type: 'text/csv; charset=shift_jis'
      end
    end
  end

  private

  def generate_dedication_counts_csv
    CSV.generate do |csv|
      csv << [ "コード", "伝道会名", "入金済み本数", "未入金本数", "合計本数" ]
      (@left_rows + @right_rows).each do |row|
        next if row[:is_blank]
        csv << [
          row[:code],
          row[:name].gsub("<br>", " "),
          row[:paid_count],
          row[:unpaid_count],
          row[:total_count]
        ]
      end
    end.encode(Encoding::SJIS, invalid: :replace, undef: :replace)
  end
end
d
end
d
