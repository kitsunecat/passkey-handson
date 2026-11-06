WebAuthn.configure do |config|
  # パスキーを使ってよいページのURL。ブラウザから届くデータ（clientDataJSON）の origin と照合する
  config.allowed_origins = [ "http://localhost:3000" ]

  # パスキーが紐づくドメイン（RP ID。RP はこのアプリのこと）。パスキーはこのドメインでしか使えない
  config.rp_id = "localhost"

  # パスキー作成時にブラウザや認証器に表示されるサービス名
  config.rp_name = "Passkey Hands-on"
end
