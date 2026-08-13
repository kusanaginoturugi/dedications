class Event < ApplicationRecord
  has_many :pre_event_quantities, dependent: :destroy
end
