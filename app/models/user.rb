class User < ApplicationRecord
  has_secure_password

  has_many :orders, dependent: :restrict_with_exception

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
end
