class Congregation < ApplicationRecord
  has_many :orders, dependent: :restrict_with_exception

  normalizes :code, :old_code, with: ->(value) { value.to_s.strip.presence }
  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  scope :search_by_query, ->(query) {
    normalized_query = query.to_s.strip
    digits = normalized_query.gsub(/\D/, "")
    escaped_query = sanitize_sql_like(normalized_query)

    scope = none
    scope = scope.or(where("code LIKE ? OR old_code LIKE ?", "#{digits}%", "#{digits}%")) if digits.length >= 2
    scope = scope.or(where("name LIKE ?", "%#{escaped_query}%")) if normalized_query.length >= 2
    scope.order(:code, :name)
  }

  def self.resolve_query(query)
    normalized_query = query.to_s.strip
    return nil if normalized_query.blank?

    exact_match = find_by(code: normalized_query) || find_by(old_code: normalized_query) || find_by(name: normalized_query)
    return exact_match if exact_match

    matches = search_by_query(normalized_query).limit(2).to_a
    matches.one? ? matches.first : nil
  end
end
