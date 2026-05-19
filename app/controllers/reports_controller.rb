require "csv"
require "prawn"
require "prawn/table"

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
    @rows = build_pre_event_rows

    respond_to do |format|
      format.html
      format.csv do
        filename = "前夜祭・当日_#{Date.current.strftime('%Y%m%d')}.csv"
        send_data generate_pre_event_csv, filename: filename, type: "text/csv; charset=shift_jis"
      end
      format.pdf do
        filename = "前夜祭・当日_#{Date.current.strftime('%Y%m%d')}.pdf"
        response.headers["Cache-Control"] = "no-store"
        send_data generate_pre_event_pdf,
          filename: filename,
          type: "application/pdf",
          disposition: "attachment"
      end
    end
  end

  def proxy_inventory
    @rows = build_proxy_inventory_rows
    @proxy_totals = calculate_proxy_totals(@rows)

    respond_to do |format|
      format.html
      format.csv do
        filename = "代理・在庫_#{Date.current.strftime('%Y%m%d')}.csv"
        send_data generate_proxy_inventory_csv, filename: filename, type: "text/csv; charset=shift_jis"
      end
      format.pdf do
        filename = "代理・在庫_#{Date.current.strftime('%Y%m%d')}.pdf"
        response.headers["Cache-Control"] = "no-store"
        send_data generate_proxy_inventory_pdf,
          filename: filename,
          type: "application/pdf",
          disposition: "attachment"
      end
    end
  end

  def dedication_counts
    @form_type = params[:form_type]
    if @form_type.present?
      @form_label = Order.form_definition_for(@form_type).fetch(:plain_label)
    end

    # 左列の定義
    left_codes = [
      "10121", "10122", "10131", "10141",
      :blank,
      "20201", "20301", "20401", "20501", "20603", "20605", "20606", "20701",
      :blank,
      "31101", "31201", "31305", "31304", "31303", "31407", "32204", "32205", "31901",
      :blank,
      "92001", "41505", :blank, "41605", "42153", "42154", "42152", "42110", "42111", "42303", "42304", "42305", "42403", "42404", "42411", "42410", "42407", "42408"
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
      "90000", "10000", "90001", "10001" # 弥勒寺, 聖治命院, 加賀御神水, 聖龍華院
    ]

    # 名称変更の定義
    name_overrides = {
      "41505" => "新潟公壇",
      "41605" => "北陸公壇",
      "63302" => "岡山北大楽伝道会",
      "90000" => "弥勒寺",
      "10000" => "聖治命院(モンゴル)",
      "90001" => "(株)加賀御神水",
      "10001" => "聖龍華院"
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

      orders = scoped_orders.where(congregation: congregation)
      orders = orders.where(form_type: @form_type) if @form_type.present?
      paid_count = orders.select(&:paid?).sum { |order| order.total_quantity.to_i }
      unpaid_count = orders.reject(&:paid?).sum { |order| order.total_quantity.to_i }

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
    @dedication_totals = dedication_count_totals(@left_rows + @right_rows)
    @right_rows << { is_blank: true }
    @right_rows << @dedication_totals.merge(is_total: true, name: "合計")

    respond_to do |format|
      format.html
      format.csv do
        filename = "#{@form_label || '各種代理奉納合計'}_#{Date.current.strftime('%Y%m%d')}.csv"
        send_data generate_dedication_counts_csv, filename: filename, type: "text/csv; charset=shift_jis"
      end
      format.pdf do
        filename = "#{@form_label || '各種代理奉納合計'}_#{Date.current.strftime('%Y%m%d')}.pdf"
        response.headers["Cache-Control"] = "no-store"
        send_data generate_dedication_counts_pdf,
          filename: filename,
          type: "application/pdf",
          disposition: "attachment"
      end
    end
  end

  private

  def build_pre_event_rows
    quantities = params[:quantities] || {}
    PRE_EVENT_ITEMS.each_with_index.map do |item, index|
      quantity = quantities[index.to_s].to_i
      item.merge(
        quantity: quantity,
        sales: quantity * item.fetch(:unit_price),
        seiin_amount: quantity * item.fetch(:refund_unit),
        miroku_amount: quantity * item.fetch(:miroku_unit)
      )
    end
  end

  def build_proxy_inventory_rows
    Order::FORM_DEFINITIONS.map do |form_type, definition|
      quantity = scoped_orders.where(form_type:).sum { |order| order.total_quantity.to_i }
      {
        label: definition.fetch(:report_label),
        unit_price: definition.fetch(:unit_price),
        quantity: quantity,
        sales: quantity * definition.fetch(:unit_price),
        refund_unit: definition.fetch(:refund_unit),
        seiin_amount: quantity * definition.fetch(:refund_unit),
        miroku_unit: definition.fetch(:miroku_unit),
        miroku_amount: quantity * definition.fetch(:miroku_unit)
      }
    end
  end

  def calculate_proxy_totals(rows)
    {
      quantity: rows.sum { |row| row[:quantity] },
      sales: rows.sum { |row| row[:sales] },
      seiin_amount: rows.sum { |row| row[:seiin_amount] },
      miroku_amount: rows.sum { |row| row[:miroku_amount] }
    }
  end

  def dedication_count_totals(rows)
    countable_rows = rows.reject { |row| row[:is_blank] }
    {
      paid_count: countable_rows.sum { |row| row[:paid_count].to_i },
      unpaid_count: countable_rows.sum { |row| row[:unpaid_count].to_i },
      total_count: countable_rows.sum { |row| row[:total_count].to_i }
    }
  end

  def generate_pre_event_pdf
    headers = [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
    rows = @rows.map do |row|
      [
        report_label(row),
        yen(row[:unit_price]),
        row[:quantity],
        yen(row[:sales]),
        yen(row[:refund_unit]),
        yen(row[:seiin_amount]),
        yen(row[:miroku_unit]),
        yen(row[:miroku_amount])
      ]
    end
    totals = [
      "合計",
      "-",
      @rows.sum { |row| row[:quantity].to_i },
      yen(@rows.sum { |row| row[:sales].to_i }),
      "-",
      yen(@rows.sum { |row| row[:seiin_amount].to_i }),
      "-",
      yen(@rows.sum { |row| row[:miroku_amount].to_i })
    ]

    generate_full_page_table_pdf("帳票: 前夜祭・当日", "還付.ods の「前夜祭・当日」シート相当です。", headers, rows, totals)
  end

  def generate_proxy_inventory_pdf
    headers = [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
    rows = @rows.map do |row|
      [
        report_label(row),
        yen(row[:unit_price]),
        row[:quantity],
        yen(row[:sales]),
        yen(row[:refund_unit]),
        yen(row[:seiin_amount]),
        yen(row[:miroku_unit]),
        yen(row[:miroku_amount])
      ]
    end
    totals = [
      "合計",
      "-",
      "#{@proxy_totals[:quantity]} 本",
      yen(@proxy_totals[:sales]),
      "-",
      yen(@proxy_totals[:seiin_amount]),
      "-",
      yen(@proxy_totals[:miroku_amount])
    ]

    generate_full_page_table_pdf("帳票: 代理・在庫", "代理奉納入力データから、代理・在庫シート相当の集計を表示します。", headers, rows, totals)
  end

  def generate_full_page_table_pdf(title, lead, headers, rows, totals)
    Prawn::Document.new(page_size: "A4", margin: [ 24, 18, 24, 18 ]) do |pdf|
      configure_pdf_font(pdf)
      pdf.text title, size: 18, style: :bold
      pdf.move_down 6
      pdf.text lead, size: 10
      pdf.move_down 12

      table_rows = [ headers ] + rows + [ totals ]
      row_height = [ (pdf.cursor - 4) / table_rows.size, 34 ].max

      pdf.table(
        table_rows,
        header: true,
        width: pdf.bounds.width,
        column_widths: [
          pdf.bounds.width * 0.23,
          pdf.bounds.width * 0.11,
          pdf.bounds.width * 0.09,
          pdf.bounds.width * 0.12,
          pdf.bounds.width * 0.11,
          pdf.bounds.width * 0.12,
          pdf.bounds.width * 0.1,
          pdf.bounds.width * 0.12
        ],
        cell_style: {
          size: 10,
          height: row_height,
          padding: [ 8, 5 ],
          borders: [ :bottom ],
          border_color: "D7DFEF",
          overflow: :shrink_to_fit,
          min_font_size: 7,
          valign: :center
        }
      ) do
        row(0).background_color = "F3E6F2"
        row(0).font_style = :bold
        row(table_rows.size - 1).background_color = "F3E6F2"
        row(table_rows.size - 1).font_style = :bold
        columns(1..7).align = :right
      end
    end.render
  end

  def generate_dedication_counts_pdf
    title = @form_label || "各種代理奉納（合計）"
    Prawn::Document.new(page_size: "A4", margin: [ 6, 6, 6, 6 ]) do |pdf|
      configure_pdf_font(pdf)
      pdf.text "帳票: #{title}", size: 18, style: :bold
      pdf.move_down 5

      start_cursor = pdf.cursor
      column_gap = 22
      column_width = (pdf.bounds.width - column_gap) / 2
      max_row_count = [ @left_rows.size, @right_rows.size ].max + 1
      row_height = (start_cursor / max_row_count.to_f).floor

      pdf.bounding_box([ 0, start_cursor ], width: column_width) do
        draw_dedication_counts_table(pdf, @left_rows, column_width, row_height)
      end

      pdf.bounding_box([ column_width + column_gap, start_cursor ], width: column_width) do
        draw_dedication_counts_table(pdf, @right_rows, column_width, row_height)
      end
    end.render
  end

  def draw_dedication_counts_table(pdf, rows, width, row_height)
    table_rows = [
      [ "伝道会", "入金済み", "未入金", "合計本数" ]
    ] + rows.map do |row|
      if row[:is_blank]
        [ " ", " ", " ", " " ]
      elsif row[:is_total]
        [
          row[:name],
          pdf_count(row[:paid_count]),
          pdf_count(row[:unpaid_count]),
          "#{pdf_count(row[:total_count])} 本"
        ]
      else
        [
          row[:name].to_s.gsub("<br>", " "),
          pdf_count(row[:paid_count]),
          pdf_count(row[:unpaid_count]),
          "#{pdf_count(row[:total_count])} 本"
        ]
      end
    end

    pdf.table(
      table_rows,
      header: true,
      width: width,
      column_widths: [ width * 0.37, width * 0.21, width * 0.21, width * 0.21 ],
      cell_style: {
        size: 11.2,
        height: row_height,
        padding: [ 1.2, 1.8 ],
        borders: [ :bottom ],
        border_color: "D7DFEF",
        overflow: :shrink_to_fit,
        min_font_size: 8.5,
        valign: :center
      }
    ) do
      row(0).background_color = "F3E6F2"
      row(0).font_style = :bold
      columns(1..3).align = :right
      if rows.last&.fetch(:is_total, false)
        row(table_rows.size - 1).font_style = :bold
        row(table_rows.size - 1).text_color = "1F2937"
      end
    end
  end

  def pdf_count(value)
    value.to_i.to_s.tr("0-9", "０-９")
  end

  def configure_pdf_font(pdf)
    font_path = [
      Rails.root.join("app/assets/fonts/NotoSansJP.ttf").to_s,
      "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
      "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
    ].find { |path| File.exist?(path) }

    return unless font_path

    pdf.font_families.update("Japanese" => { normal: font_path, bold: font_path })
    pdf.font "Japanese"
  end

  def generate_pre_event_csv
    CSV.generate do |csv|
      csv << [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
      @rows.each do |row|
        csv << [
          report_label(row),
          row[:unit_price],
          row[:quantity],
          row[:sales],
          row[:refund_unit],
          row[:seiin_amount],
          row[:miroku_unit],
          row[:miroku_amount]
        ]
      end
      csv << [
        "合計",
        "-",
        @rows.sum { |row| row[:quantity].to_i },
        @rows.sum { |row| row[:sales].to_i },
        "-",
        @rows.sum { |row| row[:seiin_amount].to_i },
        "-",
        @rows.sum { |row| row[:miroku_amount].to_i }
      ]
    end.encode(Encoding::SJIS, invalid: :replace, undef: :replace)
  end

  def generate_proxy_inventory_csv
    CSV.generate do |csv|
      csv << [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
      @rows.each do |row|
        csv << [
          report_label(row),
          row[:unit_price],
          row[:quantity],
          row[:sales],
          row[:refund_unit],
          row[:seiin_amount],
          row[:miroku_unit],
          row[:miroku_amount]
        ]
      end
      csv << [
        "合計",
        "-",
        @proxy_totals[:quantity],
        @proxy_totals[:sales],
        "-",
        @proxy_totals[:seiin_amount],
        "-",
        @proxy_totals[:miroku_amount]
      ]
    end.encode(Encoding::SJIS, invalid: :replace, undef: :replace)
  end

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

  def report_label(row)
    row[:plain_label].presence || row[:label].to_s.gsub("<br>", "").gsub(/\s+/, "")
  end

  def yen(value)
    "¥#{value.to_i.to_fs(:delimited)}"
  end

  def scoped_orders
    return Order.all unless current_event

    Order.where(event: current_event).or(Order.where(event_id: nil))
  end
end
