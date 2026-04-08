class Order < ApplicationRecord
  FORM_DEFINITIONS = {
    "wish_fulfillment_staff" => {
      label: "八大明王如意棒",
      unit_price: 2000
    },
    "sankai_ryuge_pillar" => {
      label: "三會龍華之御柱",
      unit_price: 500
    },
    "sanki_reiboku" => {
      label: "三期滅劫之霊木",
      unit_price: 800
    }
  }.freeze

  belongs_to :user
  belongs_to :congregation

  normalizes :form_type, with: ->(value) { value.to_s.strip.presence }

  validates :page_number, numericality: { greater_than: 0, only_integer: true }
  validates :form_type, inclusion: { in: FORM_DEFINITIONS.keys }
  validates :congregation, :user, presence: true
  validates :serial_number_start, :serial_number_end,
    numericality: { only_integer: true, allow_nil: true }
  validate :serial_number_range_is_valid
  validate :page_number_is_unique_within_form_type

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

  def total_quantity
    return nil if serial_number_start.blank? || serial_number_end.blank?

    serial_number_end - serial_number_start + 1
  end

  def total_amount
    return nil if total_quantity.blank?

    total_quantity * form_definition.fetch(:unit_price)
  end

  def serial_number_range_label
    return nil if serial_number_start.blank? || serial_number_end.blank?

    "#{serial_number_start}〜#{serial_number_end}"
  end

  private

  def serial_number_range_is_valid
    return if serial_number_start.blank? || serial_number_end.blank?
    return if serial_number_end >= serial_number_start

    errors.add(:serial_number_end, "は通し番号(開始)以上にしてください")
  end

  def page_number_is_unique_within_form_type
    return if page_number.blank? || form_type.blank?
    return unless self.class.where(form_type:, page_number:).where.not(id: id).exists?

    errors.add(:page_number, "は同じ注文書種類ですでに使われています")
  end
end
