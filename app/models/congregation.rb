class Congregation < ApplicationRecord
  has_many :orders, dependent: :restrict_with_exception

  normalizes :code, :old_code, with: ->(value) { value.to_s.strip.presence }
  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  scope :search_by_code_prefix, ->(query) {
    sanitized = query.to_s.gsub(/\D/, "")
    where("code LIKE ?", "#{sanitized}%").order(:code, :name)
  }
end
