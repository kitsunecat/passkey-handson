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

  test "preferred で UVなしの認証なら、まだログインさせずワンタイムコードの入力に進める" do
    log_in_with(user_verified: false)

    assert_equal "preferred", @options["userVerification"]
    assert_response :success
    assert_equal new_second_factor_path, response.parsed_body["redirect_to"]
    get root_path
    assert_select "strong", { text: "alice@example.com", count: 0 }
  end

  test "UVなしの認証のあと、正しいワンタイムコードを入力するとログインでき、UVフラグ false が表示される" do
    log_in_with(user_verified: false)
    post second_factor_path, params: { code: SecondFactorsController::VALID_CODE }

    assert_redirected_to root_path
    get root_path
    assert_select "strong", "alice@example.com"
    assert_select ".result dd code", "false"
    assert_match "入力した", response.body
  end

  test "UVなしの認証のあと、違うワンタイムコードではログインできない" do
    log_in_with(user_verified: false)
    post second_factor_path, params: { code: "000000" }

    assert_response :unprocessable_content
    assert_match "ワンタイムコードが違います", response.body
    get root_path
    assert_select "strong", { text: "alice@example.com", count: 0 }
  end

  test "パスキー認証をしていなければ、ワンタイムコードの画面には進めない" do
    get new_second_factor_path
    assert_redirected_to root_path

    post second_factor_path, params: { code: SecondFactorsController::VALID_CODE }
    assert_redirected_to root_path
    get root_path
    assert_select "strong", { text: "alice@example.com", count: 0 }
  end

  test "有効期限が切れたら、ワンタイムコードを入力してもログインできない" do
    log_in_with(user_verified: false)
    travel SecondFactorsController::EXPIRES_IN + 1.second do
      post second_factor_path, params: { code: SecondFactorsController::VALID_CODE }
    end

    assert_redirected_to root_path
    get root_path
    assert_select "strong", { text: "alice@example.com", count: 0 }
  end

  test "UVありの認証なら、ワンタイムコードなしでログインできる" do
    log_in_with(user_verified: true)

    assert_equal root_path, response.parsed_body["redirect_to"]
    get root_path
    assert_select "strong", "alice@example.com"
    assert_match "不要", response.body
  end

  test "required なら、UVなしの認証ではログインできない" do
    patch user_verification_setting_path, params: { user_verification: "required" }
    log_in_with(user_verified: false)

    assert_equal "required", @options["userVerification"]
    assert_response :unprocessable_content
    assert_match "本人確認", response.parsed_body["error"]
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

  test "本人確認しない認証器を再現する設定なら、届いた UV が true でも false とみなしてワンタイムコードを求める" do
    patch user_verification_setting_path, params: { user_verification: "discouraged", simulate_no_user_verification: "1" }
    log_in_with(user_verified: true)

    assert_equal "discouraged", @options["userVerification"]
    assert_equal new_second_factor_path, response.parsed_body["redirect_to"]

    post second_factor_path, params: { code: SecondFactorsController::VALID_CODE }
    get root_path
    assert_select ".result dd code", "false"
    assert_match "認証器から届いた値は <code>true</code>", response.body
  end

  test "required で本人確認しない認証器を再現すると、届いた UV が true でもサーバーが拒否する" do
    patch user_verification_setting_path, params: { user_verification: "required", simulate_no_user_verification: "1" }
    log_in_with(user_verified: true)

    assert_response :unprocessable_content
    assert_match "本人確認", response.parsed_body["error"]
  end

  test "オプション発行後に再現の設定をオフにしても、発行時の設定で処理する" do
    patch user_verification_setting_path, params: { user_verification: "preferred", simulate_no_user_verification: "1" }
    post session_options_path, as: :json
    challenge = response.parsed_body["challenge"]
    patch user_verification_setting_path, params: { user_verification: "preferred", simulate_no_user_verification: "0" }

    credential = fake_client.get(challenge: challenge, user_verified: true,
                                 user_handle: WebAuthn.standard_encoder.decode(@alice.webauthn_id))
    post session_path, params: { credential: credential }, as: :json
    assert_equal new_second_factor_path, response.parsed_body["redirect_to"]
  end

  test "discouraged なら、UVなしの認証でも拒否せず、ワンタイムコードの入力に進める" do
    patch user_verification_setting_path, params: { user_verification: "discouraged" }
    log_in_with(user_verified: false)

    assert_equal "discouraged", @options["userVerification"]
    assert_response :success
    assert_equal new_second_factor_path, response.parsed_body["redirect_to"]
  end

  test "不正な値には切り替えられない" do
    patch user_verification_setting_path, params: { user_verification: "none" }
    post session_options_path, as: :json
    assert_equal "preferred", response.parsed_body["userVerification"]
  end
end
