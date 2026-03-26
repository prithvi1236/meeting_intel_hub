class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def password_reset_token
    generate_token_for(:password_reset)
  end
end
