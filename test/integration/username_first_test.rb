require "test_helper"

# お題3：ユーザーネームファースト vs ユーザーネームレス
class UsernameFirstTest < ActionDispatch::IntegrationTest
  setup do
    register(email: "alice@example.com")
    @alice = User.find_by!(email: "alice@example.com")
    delete session_path
  end

  test "メールアドレスを送ると、そのユーザーのパスキーだけが allowCredentials に入る" do
    bob_client = WebAuthn::FakeClient.new("http://localhost:3000")
    register(email: "bob@example.com", client: bob_client)
    delete session_path

    post session_options_path, params: { email: "alice@example.com" }, as: :json

    allowed_ids = response.parsed_body["allowCredentials"].map { |c| c["id"] }
    assert_equal @alice.credentials.pluck(:external_id), allowed_ids
  end

  test "メールアドレスを送らないと、allowCredentials は空（ユーザーネームレス）" do
    post session_options_path, as: :json
    assert_empty response.parsed_body["allowCredentials"].to_a
  end

  test "ユーザーネームファーストなら、user handle が返らないパスキー（Discoverable でない）でもログインできる" do
    post session_options_path, params: { email: "alice@example.com" }, as: :json
    options = response.parsed_body

    credential = fake_client.get(
      challenge: options["challenge"],
      allow_credentials: options["allowCredentials"].map { |c| c["id"] },
      user_verified: true,
      user_handle: nil
    )
    post session_path, params: { credential: credential }, as: :json

    assert_response :success
    get root_path
    assert_select "strong", "alice@example.com"
  end

  test "メールアドレスで特定したユーザーとは別人のパスキーではログインできない" do
    bob_client = WebAuthn::FakeClient.new("http://localhost:3000")
    register(email: "bob@example.com", client: bob_client)
    delete session_path

    post session_options_path, params: { email: "alice@example.com" }, as: :json
    credential = bob_client.get(challenge: response.parsed_body["challenge"], user_verified: true)
    post session_path, params: { credential: credential }, as: :json

    assert_response :unprocessable_content
    assert_equal "パスキーの持ち主が一致しません", response.parsed_body["error"]
  end

  test "登録されていないメールアドレスではオプションを返さない" do
    post session_options_path, params: { email: "nobody@example.com" }, as: :json
    assert_response :unprocessable_content
  end
end
