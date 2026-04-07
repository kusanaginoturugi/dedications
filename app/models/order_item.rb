class OrderItem < ApplicationRecord
  belongs_to :order

  normalizes :entry_number, :donor_name, :wish, with: ->(value) { value.to_s.strip.presence }

  validates :donor_name, presence: true, if: :filled_row?
  validates :quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }, if: :filled_row?

  before_validation do
    self.quantity = quantity.to_i
    self.amount = quantity.to_i * order.form_definition.fetch(:unit_price)
  end

  def filled_row?
    entry_number.present? || donor_name.present? || wish.present? || quantity.to_i.positive?
  end
end
