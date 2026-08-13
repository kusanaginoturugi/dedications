class Event < ApplicationRecord
  has_many :pre_event_quantities, dependent: :destroy
  has_many :proxy_inventory_quantities, dependent: :destroy
end
