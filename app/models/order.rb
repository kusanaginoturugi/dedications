class Order < ApplicationRecord
  FORM_DEFINITIONS = {
    "wish_fulfillment_staff" => {
      label: "八大明王如意棒",
      plain_label: "八大明王如意棒",
      unit_price: 2000,
      refund_unit: 800,
      miroku_unit: 1200,
      report_label: "明王如意棒"
    },
    "sankai_ryuge_pillar" => {
      label: "三會龍華\n之御柱",
      plain_label: "三會龍華之御柱",
      unit_price: 500,
      refund_unit: 150,
      miroku_unit: 350,
      report_label: "三會龍華\n之御柱"
    },
    "sanki_reiboku" => {
      label: "三期滅劫\n之霊木",
      plain_label: "三期滅劫之霊木",
      unit_price: 800,
      refund_unit: 100,
      miroku_unit: 700,
      report_label: "三期滅劫\n之霊木"
    }
  }.freeze

  belongs_to :user
  belongs_to :congregation
  belongs_to :event, optional: true

  normalizes :form_type, with: ->(value) { value.to_s.strip.presence }

  validates :page_number, numericality: { greater_than: 0, only_integer: true }
  validates :form_type, inclusion: { in: FORM_DEFINITIONS.keys }
  validates :congregation, :user, presence: true
  validates :serial_number_start, :serial_number_end,
    numericality: { only_integer: true, allow_nil: true }
  validate :serial_number_range_is_valid
  validate :serial_number_range_is_not_taken
  validate :page_number_is_unique_within_form_type

  def self.form_options
    FORM_DEFINITIONS.map { |key, definition| [ definition.fetch(:plain_label), key ] }
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

  def plain_form_label
    form_definition.fetch(:plain_label)
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

  def serial_number_range_is_not_taken
    return if form_type.blank? || serial_number_start.blank? || serial_number_end.blank?

    scope = self.class.where(form_type: form_type)
    scope = scope.where.not(id: id) if id.present?

    overlap_exists = scope.where("serial_number_start <= ? AND serial_number_end >= ?", serial_number_end, serial_number_start).exists?

    if overlap_exists
      errors.add(:base, "通し番号は同じ申込書種類ですでに使われています。")
    end
  end

  def page_number_is_unique_within_form_type
    return if page_number.blank? || form_type.blank?
    return unless self.class.where(form_type:, page_number:).where.not(id: id).exists?

    errors.add(:page_number, "は同じ申込書種類ですでに使われています")
  end
end
