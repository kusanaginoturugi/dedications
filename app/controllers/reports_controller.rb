class ReportsController < ApplicationController
  PRE_EVENT_ITEMS = [
    { label: "弥勒収円大護摩板", unit_price: 4000, refund_unit: 2000, miroku_unit: 2000 },
    { label: "各種平定之御柱", unit_price: 2000, refund_unit: 300, miroku_unit: 1700 },
    { label: "三期滅劫之霊木", unit_price: 800, refund_unit: 100, miroku_unit: 700 },
    { label: "三會龍華之御柱", unit_price: 500, refund_unit: 150, miroku_unit: 350 },
    { label: "その他のハッピーポール", unit_price: 500, refund_unit: 150, miroku_unit: 350 },
    { label: "灶君護摩木・収天護摩木", unit_price: 200, refund_unit: 60, miroku_unit: 140 },
    { label: "地護摩木", unit_price: 100, refund_unit: 50, miroku_unit: 50 },
    { label: "天地免劫護摩木", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "原佛子結集の護摩木", unit_price: 40, refund_unit: 0, miroku_unit: 40 },
    { label: "おかげ符", unit_price: 100, refund_unit: 40, miroku_unit: 60 },
    { label: "仙丹茶（禄存五聖杯）", unit_price: 300, refund_unit: 0, miroku_unit: 300 },
    { label: "特別祈祷", unit_price: 5000, refund_unit: 1000, miroku_unit: 4000 },
    { label: "明王如意棒", unit_price: 2000, refund_unit: 800, miroku_unit: 1200 },
    { label: "八大明王札", unit_price: 600, refund_unit: 600, miroku_unit: 0 },
    { label: "幟", unit_price: 3000, refund_unit: 0, miroku_unit: 3000 },
    { label: "泉珠卜占", unit_price: 500, refund_unit: 200, miroku_unit: 300 }
  ].freeze

  before_action :require_sign_in!

  def pre_event
    @rows = PRE_EVENT_ITEMS.map do |item|
      item.merge(quantity: 0, sales: 0, seiin_amount: 0, miroku_amount: 0)
    end
  end

  def proxy_inventory
    @rows = Order::FORM_DEFINITIONS.map do |form_type, definition|
      quantity = Order.where(form_type:).sum { |order| order.total_quantity.to_i }
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
    rows = Congregation.order(:code).map do |congregation|
      orders = Order.where(congregation:)
      paid_count = orders.select(&:paid?).sum { |order| order.total_quantity.to_i }
      unpaid_count = orders.reject(&:paid?).sum { |order| order.total_quantity.to_i }
      {
        congregation:,
        paid_count:,
        unpaid_count:,
        total_count: paid_count + unpaid_count
      }
    end
    midpoint = (rows.length / 2.0).ceil
    @left_rows = rows.first(midpoint)
    @right_rows = rows.drop(midpoint)
  end
end
