# パスキー1件分の「公開鍵クレデンシャル」。
# サーバーに保存するのは公開鍵だけで、秘密鍵は認証器の中から出てこない。
class Credential < ApplicationRecord
  # お題4：1ユーザーが登録できるパスキーの上限（講演のSmartHRと同じ15個）
  MAX_PER_USER = 15
  DEFAULT_NICKNAME = "パスキー"

  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :nickname, presence: true, length: { maximum: 50 }
  validate :within_limit, on: :create

  # 初期名：User-Agent のブラウザ名、わからなければ「パスキー」。
  # すでに同じ名前があれば「Chrome (2)」のように番号を付けて区別する
  def self.default_nickname(user_agent, existing_nicknames)
    base = browser_name(user_agent) || DEFAULT_NICKNAME
    return base unless existing_nicknames.include?(base)

    number = 2
    number += 1 while existing_nicknames.include?("#{base} (#{number})")
    "#{base} (#{number})"
  end

  def self.browser_name(user_agent)
    case user_agent.to_s
    when /Edg\// then "Edge"
    when /Firefox\// then "Firefox"
    when /Chrome\// then "Chrome"
    when /Safari\// then "Safari"
    end
  end

  private

  def within_limit
    if user && user.credentials.where.not(id: nil).count >= MAX_PER_USER
      errors.add(:base, "パスキーは#{MAX_PER_USER}個まで登録できます")
    end
  end
end
