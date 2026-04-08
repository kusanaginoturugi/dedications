class User < ApplicationRecord
  has_secure_password

  has_many :orders, dependent: :restrict_with_exception

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def display_name
    name.presence || email
  end
end
