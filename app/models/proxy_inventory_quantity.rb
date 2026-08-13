class ProxyInventoryQuantity < ApplicationRecord
  belongs_to :event

  validates :item_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
