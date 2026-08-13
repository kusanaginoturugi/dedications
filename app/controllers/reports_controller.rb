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
    { label: "天地免劫護摩木", plain_label: "天地免劫護摩木", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "原佛子結集の護摩木", plain_label: "原佛子結集の護摩木", unit_price: 40, refund_unit: 0, miroku_unit: 40 },
    { label: "おかげ符", plain_label: "おかげ符", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "仙丹茶\n（禄存五聖杯）", plain_label: "仙丹茶（禄存五聖杯）", unit_price: 300, refund_unit: 0, miroku_unit: 300 },
    { label: "特別祈祷", plain_label: "特別祈祷", unit_price: 5000, refund_unit: 1000, miroku_unit: 4000 },
    { label: "明王如意棒", plain_label: "明王如意棒", unit_price: 2000, refund_unit: 800, miroku_unit: 1200 },
    { label: "八大明王札", plain_label: "八大明王札", unit_price: 600, refund_unit: 600, miroku_unit: 0 },
    { label: "幟", plain_label: "幟", unit_price: 3000, refund_unit: 0, miroku_unit: 3000 },
    { label: "泉珠卜占", plain_label: "泉珠卜占", unit_price: 500, refund_unit: 200, miroku_unit: 300 }
  ].freeze

  PROXY_INVENTORY_ITEMS = [
    { label: "弥勒収円大護摩板", unit_price: 4000, refund_unit: 2000, miroku_unit: 2000 },
    { label: "三期滅劫之霊木", unit_price: 800, refund_unit: 100, miroku_unit: 700, form_type: "sanki_reiboku" },
    { label: "三會龍華之御柱", unit_price: 500, refund_unit: 150, miroku_unit: 350, form_type: "sankai_ryuge_pillar" },
    { label: "特別祈祷", unit_price: 5000, refund_unit: 1000, miroku_unit: 4000 },
    { label: "明王如意棒", unit_price: 2000, refund_unit: 800, miroku_unit: 1200, form_type: "wish_fulfillment_staff" },
    { label: "幟", unit_price: 3000, refund_unit: nil, miroku_unit: 3000 }
  ].freeze

  INVENTORY_CHECK_ITEMS = [
    { label: "弥勒収円大護摩板", order_total: 60, pre_event_index: 0 },
    { label: "※各種平定之御柱", order_total: 130, pre_event_index: 1, stock_slash: true },
    { label: "※三期滅劫之霊木", order_total: 830, form_type: "sanki_reiboku", pre_event_index: 2, stock_slash: true },
    { label: "※三會龍華之御柱", order_total: 650, form_type: "sankai_ryuge_pillar", pre_event_index: 3, stock_slash: true },
    { label: "明王如意棒", order_total: 900, form_type: "wish_fulfillment_staff", pre_event_index: 12 },
    { label: "幟", stock_count: 61, proxy_quantity: 15, pre_event_index: 14 }
  ].freeze
  INVENTORY_CHECK_FIELDS = %w[
    stock_count
    order_total
    proxy_quantity
    pre_event_quantity
    remaining_count
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

  def save_pre_event
    unless current_event
      redirect_to pre_event_reports_path, alert: "保存先の回次がありません。管理者に確認してください。"
      return
    end

    unless params[:quantities].present?
      redirect_to pre_event_reports_path, alert: "奉納数が送信されませんでした。もう一度入力して保存してください。"
      return
    end

    save_pre_event_quantities
    redirect_to pre_event_reports_path, notice: "前夜祭・当日の奉納数を保存しました。"
  end

  def proxy_inventory
    @rows = build_proxy_inventory_rows
    @proxy_totals = calculate_proxy_totals(@rows)
    @pre_event_rows = build_pre_event_rows
    @pre_event_totals = calculate_pre_event_totals(@pre_event_rows)
    @grand_totals = combine_report_totals(@proxy_totals, @pre_event_totals)
    @inventory_rows = build_inventory_check_rows(@rows)

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

  def save_proxy_inventory
    unless current_event
      redirect_to proxy_inventory_reports_path, alert: "保存先の回次がありません。管理者に確認してください。"
      return
    end

    unless params[:quantities].present? || params[:inventory_checks].present?
      redirect_to proxy_inventory_reports_path, alert: "奉納数が送信されませんでした。もう一度入力して保存してください。"
      return
    end

    save_proxy_inventory_quantities
    save_inventory_check_quantities
    redirect_to proxy_inventory_reports_path, notice: "代理・在庫の奉納数を保存しました。"
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

      fellowship = Fellowship.find_by(code: code)
      # データベースにない場合も、名称変更があれば特別枠として扱う（弥勒寺など）
      if !fellowship && name_overrides.key?(code)
        fellowship = Fellowship.new(code: code, name: name_overrides[code])
      end

      return nil unless fellowship

      orders = scoped_orders.where(fellowship: fellowship)
      orders = orders.where(form_type: @form_type) if @form_type.present?
      paid_count = orders.select(&:paid?).sum { |order| order.total_quantity.to_i }
      unpaid_count = orders.reject(&:paid?).sum { |order| order.total_quantity.to_i }

      {
        is_blank: false,
        code: fellowship.code,
        name: name_overrides[fellowship.code] || fellowship.name,
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
    quantities = pre_event_quantities
    PRE_EVENT_ITEMS.each_with_index.map do |item, index|
      quantity = quantities.fetch(index, 0)
      item.merge(
        quantity: quantity,
        sales: quantity * item.fetch(:unit_price),
        seiin_amount: quantity * item.fetch(:refund_unit),
        miroku_amount: quantity * item.fetch(:miroku_unit)
      )
    end
  end

  def pre_event_quantities
    if params[:quantities].present?
      return normalized_pre_event_quantities(params[:quantities])
    end

    saved_quantities = current_event&.pre_event_quantities || PreEventQuantity.none
    saved_quantities.each_with_object({}) do |record, quantities|
      quantities[record.item_index] = record.quantity
    end
  end

  def save_pre_event_quantities
    return unless current_event

    normalized_pre_event_quantities(params[:quantities] || {}).each do |item_index, quantity|
      record = current_event.pre_event_quantities.find_or_initialize_by(item_index: item_index)
      record.quantity = quantity
      record.save!
    end
  end

  def normalized_pre_event_quantities(raw_quantities)
    raw_quantities.to_unsafe_h.each_with_object({}) do |(index, value), quantities|
      item_index = index.to_i
      next unless item_index.between?(0, PRE_EVENT_ITEMS.size - 1)

      quantities[item_index] = [ value.to_i, 0 ].max
    end
  end

  def build_proxy_inventory_rows
    PROXY_INVENTORY_ITEMS.each_with_index.map do |item, index|
      quantity = proxy_inventory_quantity_for(item, index)
      {
        label: item.fetch(:label),
        unit_price: item.fetch(:unit_price),
        quantity: quantity,
        sales: quantity ? quantity * item.fetch(:unit_price) : nil,
        refund_unit: item[:refund_unit],
        seiin_amount: quantity && item[:refund_unit] ? quantity * item.fetch(:refund_unit) : nil,
        miroku_unit: item[:miroku_unit],
        miroku_amount: quantity && item[:miroku_unit] ? quantity * item.fetch(:miroku_unit) : nil,
        form_type: item[:form_type],
        item_index: index
      }
    end
  end

  def proxy_inventory_quantity_for(item, index)
    return proxy_quantity_from_orders(item) if item[:form_type].present?

    saved_quantities = proxy_inventory_quantity_map
    return saved_quantities[index] if saved_quantities.key?(index)

    nil
  end

  def proxy_inventory_quantity_map
    @proxy_inventory_quantity_map ||= begin
      saved_quantities = current_event&.proxy_inventory_quantities || ProxyInventoryQuantity.none
      saved_quantities.each_with_object({}) do |record, quantities|
        quantities[record.item_index] = record.quantity
      end
    end
  end

  def save_proxy_inventory_quantities
    return unless current_event

    normalized_proxy_inventory_quantities(params[:quantities] || {}).each do |item_index, quantity|
      next unless proxy_inventory_manual_item_index?(item_index)

      record = current_event.proxy_inventory_quantities.find_or_initialize_by(item_index: item_index)
      record.quantity = quantity
      record.save!
    end
  end

  def normalized_proxy_inventory_quantities(raw_quantities)
    raw_quantities.to_unsafe_h.each_with_object({}) do |(index, value), quantities|
      item_index = index.to_i
      next unless item_index.between?(0, PROXY_INVENTORY_ITEMS.size - 1)

      quantities[item_index] = value.blank? ? nil : [ value.to_i, 0 ].max
    end
  end

  def proxy_inventory_manual_item_index?(item_index)
    PROXY_INVENTORY_ITEMS[item_index]&.fetch(:form_type, nil).blank?
  end

  def proxy_quantity_from_orders(item)
    scoped_orders.where(form_type: item.fetch(:form_type)).sum { |order| order.total_quantity.to_i }
  end

  def calculate_proxy_totals(rows)
    {
      sales: rows.sum { |row| row[:sales].to_i },
      seiin_amount: rows.sum { |row| row[:seiin_amount].to_i },
      miroku_amount: rows.sum { |row| row[:miroku_amount].to_i }
    }
  end

  def calculate_pre_event_totals(rows)
    {
      sales: rows.sum { |row| row[:sales].to_i },
      seiin_amount: rows.sum { |row| row[:seiin_amount].to_i },
      miroku_amount: rows.sum { |row| row[:miroku_amount].to_i }
    }
  end

  def combine_report_totals(*totals)
    {
      sales: totals.sum { |total| total[:sales].to_i },
      seiin_amount: totals.sum { |total| total[:seiin_amount].to_i },
      miroku_amount: totals.sum { |total| total[:miroku_amount].to_i }
    }
  end

  def build_inventory_check_rows(proxy_rows)
    proxy_quantities_by_form_type = proxy_rows.index_by { |row| row[:form_type] }
    proxy_quantities_by_label = proxy_rows.index_by { |row| row[:label] }
    pre_event_quantities = pre_event_quantity_map
    saved_inventory_checks = inventory_check_quantity_map

    INVENTORY_CHECK_ITEMS.each_with_index.map do |item, index|
      proxy_quantity = if item[:form_type].present?
        proxy_quantities_by_form_type.dig(item[:form_type], :quantity).to_i
      elsif item[:proxy_quantity].present?
        item.fetch(:proxy_quantity)
      else
        proxy_quantities_by_label.dig(item[:label], :quantity).to_i
      end
      pre_event_quantity = pre_event_quantities.fetch(item.fetch(:pre_event_index), 0)
      base_count = item[:order_total] || item[:stock_count]
      remaining_count = base_count.to_i - proxy_quantity - pre_event_quantity

      {
        label: item.fetch(:label),
        item_index: index,
        stock_slash: item[:stock_slash],
        stock_count: inventory_check_value(saved_inventory_checks, index, "stock_count", item[:stock_count]),
        order_total: inventory_check_value(saved_inventory_checks, index, "order_total", item[:order_total]),
        proxy_quantity: inventory_check_value(saved_inventory_checks, index, "proxy_quantity", proxy_quantity.positive? ? proxy_quantity : nil),
        pre_event_quantity: inventory_check_value(saved_inventory_checks, index, "pre_event_quantity", pre_event_quantity.positive? ? pre_event_quantity : nil),
        remaining_count: inventory_check_value(saved_inventory_checks, index, "remaining_count", remaining_count.positive? ? remaining_count : nil)
      }
    end
  end

  def inventory_check_value(saved_inventory_checks, item_index, field_name, fallback)
    key = [ item_index, field_name ]
    return saved_inventory_checks[key] if saved_inventory_checks.key?(key)

    fallback
  end

  def inventory_check_quantity_map
    @inventory_check_quantity_map ||= begin
      saved_quantities = current_event&.inventory_check_quantities || InventoryCheckQuantity.none
      saved_quantities.each_with_object({}) do |record, quantities|
        quantities[[ record.item_index, record.field_name ]] = record.quantity
      end
    end
  end

  def save_inventory_check_quantities
    return unless current_event

    normalized_inventory_check_quantities(params[:inventory_checks] || {}).each do |(item_index, field_name), quantity|
      record = current_event.inventory_check_quantities.find_or_initialize_by(item_index: item_index, field_name: field_name)
      record.quantity = quantity
      record.save!
    end
  end

  def normalized_inventory_check_quantities(raw_quantities)
    unsafe_hash(raw_quantities).each_with_object({}) do |(index, fields), quantities|
      item_index = index.to_i
      next unless item_index.between?(0, INVENTORY_CHECK_ITEMS.size - 1)

      unsafe_hash(fields).each do |field_name, value|
        next unless INVENTORY_CHECK_FIELDS.include?(field_name)

        quantities[[ item_index, field_name ]] = value.blank? ? nil : [ value.to_i, 0 ].max
      end
    end
  end

  def unsafe_hash(value)
    value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
  end

  def pre_event_quantity_map
    pre_event_quantities
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
      "-",
      yen(@rows.sum { |row| row[:sales].to_i }),
      "-",
      yen(@rows.sum { |row| row[:seiin_amount].to_i }),
      "-",
      yen(@rows.sum { |row| row[:miroku_amount].to_i })
    ]

    generate_full_page_table_pdf("帳票: 前夜祭・当日", "還付.ods の「前夜祭・当日」シート相当です。", headers, rows, totals)
  end

  def generate_proxy_inventory_pdf
    Prawn::Document.new(page_size: "A4", margin: [ 24, 18, 24, 18 ]) do |pdf|
      configure_pdf_font(pdf)
      pdf.text "聖明王院 #{current_event&.name}八大明王護摩供 売上表", size: 14, style: :bold
      pdf.move_down 4
      pdf.text "代理奉納分は表②に記入（※各伝道会からの代理奉納報告書も一緒に提出をお願いします）", size: 8.5
      pdf.move_down 6
      pdf.text "表② 代理奉納（地方代理＝護摩センター振込分）", size: 10, style: :bold
      pdf.move_down 4

      proxy_table_rows = [
        [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
      ] + @rows.map do |row|
        [
          row[:label],
          pdf_number(row[:unit_price]),
          pdf_number(row[:quantity]),
          pdf_number(row[:sales]),
          pdf_number(row[:refund_unit]),
          pdf_number(row[:seiin_amount]),
          pdf_number(row[:miroku_unit]),
          pdf_number(row[:miroku_amount])
        ]
      end

      pdf.table(proxy_table_rows, header: true, width: pdf.bounds.width, cell_style: proxy_pdf_cell_style) do
        row(0).font_style = :bold
        row(0).background_color = "F3E6F2"
        columns(1..7).align = :right
      end

      pdf.move_down 6
      pdf.table(proxy_summary_pdf_rows, width: pdf.bounds.width, cell_style: proxy_summary_pdf_cell_style) do
        columns([ 1, 3, 5 ]).align = :right
        columns([ 2, 4 ]).align = :center
        cells.font_style = :bold
        cells.border_width = 1.4
        columns([ 0, 2, 4 ]).background_color = "F3E6F2"
      end

      pdf.move_down 8
      pdf.text "※令和元年より、代理奉納の聖院還付は、みろく寺の道具請求(平成27年度までの未入金分）の方へ当てさせていただくことになりました。（4月18日の通達参照）", size: 7.5
      pdf.move_down 8
      pdf.text "道具数チェック", size: 10, style: :bold
      pdf.move_down 4

      inventory_rows = [
        [ "道具名", "在庫数", "注文数(合計)", "代理奉納数(合計)", "前日・当日売上数", "残数" ]
      ] + @inventory_rows.map do |row|
        [
          row[:label],
          inventory_stock_display(row),
          pdf_number(row[:order_total]),
          pdf_number(row[:proxy_quantity]),
          pdf_number(row[:pre_event_quantity]),
          pdf_number(row[:remaining_count])
        ]
      end

      pdf.table(inventory_rows, header: true, width: pdf.bounds.width, cell_style: proxy_pdf_cell_style) do
        row(0).font_style = :bold
        row(0).background_color = "F3E6F2"
        columns(1..5).align = :right
      end

      pdf.move_down 8
      pdf.text "報告担当者：尾ノ上裕美　連絡先：09041779036", size: 9, align: :right
    end.render
  end

  def proxy_pdf_cell_style
    {
      size: 8.2,
      padding: [ 4, 3 ],
      border_color: "444444",
      overflow: :shrink_to_fit,
      min_font_size: 5.5,
      valign: :center
    }
  end

  def proxy_summary_pdf_rows
    [
      [ "② 代理奉納合計", yen(@proxy_totals[:sales]), "※聖院分\nとして\n入金", yen(@proxy_totals[:seiin_amount]), "弥勒寺分", yen(@proxy_totals[:miroku_amount]) ],
      [ "①前日・当日売上合計", yen(@pre_event_totals[:sales]), "聖院分", yen(@pre_event_totals[:seiin_amount]), "弥勒寺分", yen(@pre_event_totals[:miroku_amount]) ],
      [ "地護摩供売上総合計（①＋②）", yen(@grand_totals[:sales]), "聖院還付\n合計", yen(@grand_totals[:seiin_amount]), "弥勒寺分\n合計", yen(@grand_totals[:miroku_amount]) ]
    ]
  end

  def proxy_summary_pdf_cell_style
    {
      size: 8.2,
      padding: [ 4, 3 ],
      border_color: "444444",
      overflow: :shrink_to_fit,
      min_font_size: 5.5,
      valign: :center
    }
  end

  def pdf_number(value)
    value.present? ? value.to_s : ""
  end

  def inventory_stock_display(row)
    row[:stock_slash] ? "／" : pdf_number(row[:stock_count])
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
      column_gap = 48
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
      column_widths: [ width * 0.32, width * 0.22, width * 0.22, width * 0.24 ],
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
        row(table_rows.size - 1).size = 11.6
        row(table_rows.size - 1).font_style = :bold
        row(table_rows.size - 1).text_color = "000000"
      end
    end
  end

  def pdf_count(value)
    value.to_i.to_s.tr("0-9", "０-９")
  end

  def configure_pdf_font(pdf)
    normal_font_path = [
      Rails.root.join("app/assets/fonts/NotoSansJP.ttf").to_s,
      "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
      "/System/Library/Fonts/Supplemental/AppleGothic.ttf"
    ].find { |path| File.exist?(path) }

    return unless normal_font_path

    bold_font_path = [
      "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
      "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
      normal_font_path
    ].find { |path| File.exist?(path) }

    pdf.font_families.update("Japanese" => { normal: normal_font_path, bold: bold_font_path })
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
        "-",
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
      csv << [ "聖明王院 #{current_event&.name}八大明王護摩供 売上表" ]
      csv << [ "代理奉納分は表②に記入（※各伝道会からの代理奉納報告書も一緒に提出をお願いします）" ]
      csv << [ "表② 代理奉納（地方代理＝護摩センター振込分）" ]
      csv << [ "道具名", "奉納料", "奉納数", "売上", "還付金", "聖院還付分", "弥勒寺", "弥勒寺入金分" ]
      @rows.each do |row|
        csv << [
          row[:label],
          row[:unit_price],
          row[:quantity],
          row[:sales],
          row[:refund_unit],
          row[:seiin_amount],
          row[:miroku_unit],
          row[:miroku_amount]
        ]
      end
      csv << [ "※聖院分　② 代理奉納合計", "", "", @proxy_totals[:sales], "", @proxy_totals[:seiin_amount], "", @proxy_totals[:miroku_amount] ]
      csv << [ "①前日・当日売上合計", "", "", @pre_event_totals[:sales], "", @pre_event_totals[:seiin_amount], "", @pre_event_totals[:miroku_amount] ]
      csv << [ "地護摩供売上総合計（①＋②）", "", "", @grand_totals[:sales], "", @grand_totals[:seiin_amount], "", @grand_totals[:miroku_amount] ]
      csv << []
      csv << [ "※令和元年より、代理奉納の聖院還付は、みろく寺の道具請求(平成27年度までの未入金分）の方へ当てさせていただくことになりました。（4月18日の通達参照）" ]
      csv << []
      csv << [ "道具数チェック" ]
      csv << [ "道具名", "在庫数", "注文数(合計)", "代理奉納数(合計)", "前日・当日売上数", "残数" ]
      @inventory_rows.each do |row|
        csv << [ row[:label], inventory_stock_display(row), row[:order_total], row[:proxy_quantity], row[:pre_event_quantity], row[:remaining_count] ]
      end
      csv << []
      csv << [ "報告担当者：尾ノ上裕美", "連絡先：09041779036" ]
    end.encode(Encoding::SJIS, invalid: :replace, undef: :replace)
  end

  def generate_dedication_counts_csv
    CSV.generate do |csv|
      csv << [ "コード", "伝道会名", "入金済み", "未入金", "合計本数" ]
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
