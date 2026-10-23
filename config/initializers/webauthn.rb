WebAuthn.configure do |config|
  # パスキーを使ってよいオリジン。ブラウザから届く clientDataJSON の origin と照合する
  config.allowed_origins = [ "http://localhost:3000" ]

  # RP ID：パスキーが紐づくドメイン。パスキーはこのRP IDのスコープ内でしか使えない
  config.rp_id = "localhost"

  # パスキー作成時にブラウザや認証器に表示されるサービス名
  config.rp_name = "Passkey Hands-on"
end
