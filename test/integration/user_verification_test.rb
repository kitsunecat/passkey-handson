require "test_helper"

# お題5：UVフラグと二要素認証
class UserVerificationTest < ActionDispatch::IntegrationTest
  setup do
    register(email: "alice@example.com")
    @alice = User.find_by!(email: "alice@example.com")
    delete session_path
  end

  def log_in_with(user_verified:)
    post session_options_path, as: :json
    @options = response.parsed_body
    credential = fake_client.get(challenge: @options["challenge"], user_verified: user_verified,
                                 user_handle: WebAuthn.standard_encoder.decode(@alice.webauthn_id))
    post session_path, params: { credential: credential }, as: :json
  end

  test "preferred なら、UVなしの認証でもログインでき、UVフラグ false が表示される" do
    log_in_with(user_verified: false)

    assert_equal "preferred", @options["userVerification"]
    assert_response :success
    get root_path
    assert_select ".result dd code", "false"
  end

  test "required なら、UVなしの認証ではログインできない" do
    patch user_verification_setting_path, params: { user_verification: "required" }
    log_in_with(user_verified: false)

    assert_equal "required", @options["userVerification"]
    assert_response :unprocessable_content
    assert_match "ユーザー検証", response.parsed_body["error"]
  end

  test "required でも、UVありの認証ならログインでき、UVフラグ true が表示される" do
    patch user_verification_setting_path, params: { user_verification: "required" }
    log_in_with(user_verified: true)

    assert_response :success
    get root_path
    assert_select ".result dd code", "true"
  end

  test "オプション発行後に設定を preferred に戻しても、発行時の required で検証される" do
    patch user_verification_setting_path, params: { user_verification: "required" }
    post session_options_path, as: :json
    challenge = response.parsed_body["challenge"]
    patch user_verification_setting_path, params: { user_verification: "preferred" }

    credential = fake_client.get(challenge: challenge, user_verified: false,
                                 user_handle: WebAuthn.standard_encoder.decode(@alice.webauthn_id))
    post session_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
  end

  test "サーバーだけ required の場合、ブラウザには discouraged と伝え、UVなしの認証は拒否する" do
    patch user_verification_setting_path, params: { user_verification: "required_server_only" }
    log_in_with(user_verified: false)

    assert_equal "discouraged", @options["userVerification"]
    assert_response :unprocessable_content
  end

  test "discouraged なら、UVなしの認証でもログインできる" do
    patch user_verification_setting_path, params: { user_verification: "discouraged" }
    log_in_with(user_verified: false)

    assert_equal "discouraged", @options["userVerification"]
    assert_response :success
  end

  test "不正な値には切り替えられない" do
    patch user_verification_setting_path, params: { user_verification: "none" }
    post session_options_path, as: :json
    assert_equal "preferred", response.parsed_body["userVerification"]
  end
end
