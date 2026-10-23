class User < ApplicationRecord
  # モデル上は複数のパスキーを持てるようにしておく（ベースのUIでは1つに制限）
  has_many :credentials, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :webauthn_id, presence: true, uniqueness: true
end
