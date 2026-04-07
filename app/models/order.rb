class Order < ApplicationRecord
  DETAIL_ROW_COUNT = 10

  FORM_DEFINITIONS = {
    "wish_fulfillment_staff" => {
      label: "八大明王如意棒代理奉納",
      unit_price: 2000
    },
    "sankai_ryuge_pillar" => {
      label: "三會龍華之御柱代理奉納",
      unit_price: 500
    },
    "sanki_reiboku" => {
      label: "三期滅劫之霊木代理奉納",
      unit_price: 800
    }
  }.freeze

  belongs_to :user
  belongs_to :congregation

  has_many :order_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :order

  accepts_nested_attributes_for :order_items, reject_if: :blank_order_item_attributes?

  normalizes :form_type, :contact_name, :phone, with: ->(value) { value.to_s.strip.presence }
  normalizes :wish, with: ->(value) { value.to_s.strip }

  validates :page_number, numericality: { greater_than: 0, only_integer: true }
  validates :form_type, inclusion: { in: FORM_DEFINITIONS.keys }
  validates :congregation, :user, presence: true

  before_validation :normalize_order_items

  def self.form_options
    FORM_DEFINITIONS.map { |key, definition| [ definition.fetch(:label), key ] }
  end

  def self.form_definition_for(form_type)
    FORM_DEFINITIONS.fetch(form_type)
  end

  def form_definition
    self.class.form_definition_for(form_type)
  end

  def form_label
    form_definition.fetch(:label)
  end

  def page_total_quantity
    order_items.sum(&:quantity)
  end

  def page_total_amount
    order_items.sum(&:amount)
  end

  def build_detail_rows
    return if form_type.blank? || !FORM_DEFINITIONS.key?(form_type)

    existing_items = order_items.sort_by(&:position)
    self.order_items = DETAIL_ROW_COUNT.times.map do |index|
      item = existing_items[index] || order_items.build
      item.position = index
      item.quantity ||= 0
      item.amount ||= 0
      item
    end
  end

  private

  def normalize_order_items
    order_items.each_with_index do |item, index|
      item.position = index if item.position.blank?
    end
  end

  def blank_order_item_attributes?(attributes)
    attributes["entry_number"].to_s.strip.empty? &&
      attributes["donor_name"].to_s.strip.empty? &&
      attributes["quantity"].to_s.strip.empty?
  end
end
