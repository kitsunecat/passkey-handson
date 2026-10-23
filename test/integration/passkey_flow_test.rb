require "test_helper"

class PasskeyFlowTest < ActionDispatch::IntegrationTest
  test "パスキーで新規登録し、ログアウト後にパスキーでログインできる" do
    register(email: "alice@example.com")
    assert_response :success
    user = User.find_by!(email: "alice@example.com")
    assert_equal 1, user.credentials.count

    get root_path
    assert_select "strong", "alice@example.com"

    delete session_path
    get root_path
    assert_select "#login-button"

    log_in_with_passkey(user)
    assert_response :success
    get root_path
    assert_select "strong", "alice@example.com"
  end

  test "登録時のオプションには Discoverable Credential の指定が含まれる" do
    post registration_options_path, params: { email: "alice@example.com" }, as: :json

    options = response.parsed_body
    assert_equal "localhost", options.dig("rp", "id")
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")
    assert options["challenge"].present?
  end

  test "チャレンジが一致しないと登録に失敗する" do
    post registration_options_path, params: { email: "alice@example.com" }, as: :json

    # サーバーが発行したものとは別のチャレンジでパスキーを作る
    credential = fake_client.create(challenge: WebAuthn.standard_encoder.encode(SecureRandom.random_bytes(32)))
    post registration_path, params: { credential: credential }, as: :json

    assert_response :unprocessable_content
    assert_nil User.find_by(email: "alice@example.com")
  end

  test "同じ認証データを2回送ると、2回目はログインに失敗する（リプレイ攻撃の防止）" do
    register(email: "alice@example.com")
    user = User.find_by!(email: "alice@example.com")
    delete session_path

    credential = log_in_with_passkey(user)
    assert_response :success
    delete session_path

    # 1回目と同じ認証データをもう一度送る
    post session_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
    get root_path
    assert_select "#login-button"
  end

  test "登録されていないパスキーではログインできない" do
    post session_options_path, as: :json
    # FakeClient は自分で作ったパスキーでしか署名できないので、別のクライアントで作ったパスキーを使う
    other_client = WebAuthn::FakeClient.new("http://localhost:3000")
    other_client.create
    credential = other_client.get(challenge: response.parsed_body["challenge"])

    post session_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
    assert_equal "このパスキーは登録されていません", response.parsed_body["error"]
  end

  test "登録済みのメールアドレスでは登録できない" do
    register(email: "alice@example.com")
    delete session_path

    post registration_options_path, params: { email: "alice@example.com" }, as: :json
    assert_response :unprocessable_content
  end
end
