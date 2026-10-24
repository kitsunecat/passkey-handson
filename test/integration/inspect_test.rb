require "test_helper"

# お題1：中身を覗く
class InspectTest < ActionDispatch::IntegrationTest
  test "登録の結果として、クレデンシャルID・AAGUID・UP/UVフラグ・公開鍵が返る（秘密鍵は届かない）" do
    register(email: "alice@example.com")

    inspection = response.parsed_body["inspection"]
    assert_equal Credential.last.external_id, inspection["credential_id"]
    assert_equal Credential.last.public_key, inspection["public_key"]
    assert inspection["aaguid"].present?
    assert_equal true, inspection["user_present"]
    assert_equal true, inspection["user_verified"]
    assert_equal "（サーバーには届かない）", inspection["private_key"]
  end

  test "ログインのたびに sign_count とチャレンジが変わる" do
    register(email: "alice@example.com")
    user = User.find_by!(email: "alice@example.com")

    log_in_with_passkey(user)
    first = response.parsed_body["inspection"]
    log_in_with_passkey(user)
    second = response.parsed_body["inspection"]

    assert_not_equal first["challenge"], second["challenge"]
    assert_not_equal first["sign_count"], second["sign_count"]
  end

  test "リプレイすると、失敗の原因も返る" do
    register(email: "alice@example.com")
    user = User.find_by!(email: "alice@example.com")
    credential = log_in_with_passkey(user)
    csrf_token = response.parsed_body["csrf_token"]
    assert csrf_token.present?

    post session_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
    assert_equal "no authentication challenge in session", response.parsed_body["reason"]

    # 新しいチャレンジを発行してもらってから同じデータを送っても、チャレンジが一致しないので失敗する
    post session_options_path, as: :json
    post session_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
    assert_match "ChallengeVerificationError", response.parsed_body["reason"]
  end
end
