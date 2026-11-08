# 登録されたパスキー1件分の情報（ID・公開鍵・使用回数など）。
# サーバーに保存するのは公開鍵だけで、秘密鍵は認証器の中から出てこない。
class Credential < ApplicationRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
