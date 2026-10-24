require "test_helper"

# お題4：複数パスキーと管理画面
class MultiplePasskeysTest < ActionDispatch::IntegrationTest
  CHROME_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

  setup do
    register(email: "alice@example.com")
    @alice = User.find_by!(email: "alice@example.com")
  end

  def add_passkey(client: WebAuthn::FakeClient.new("http://localhost:3000"), headers: {})
    post options_credentials_path, as: :json
    options = response.parsed_body
    credential = client.create(challenge: options["challenge"], user_verified: true) if response.successful?
    post credentials_path, params: { credential: credential }, headers: headers, as: :json
    options
  end

  test "別の認証器でパスキーを追加でき、一覧に2件並ぶ" do
    add_passkey
    assert_response :success
    assert_equal 2, @alice.credentials.count

    get credentials_path
    assert_select "table.credentials tbody tr", 2
  end

  test "追加登録のオプションには、登録済みのパスキーが excludeCredentials として入る" do
    post options_credentials_path, as: :json
    excluded = response.parsed_body["excludeCredentials"].map { |c| c["id"] }
    assert_equal @alice.credentials.pluck(:external_id), excluded
  end

  test "同じパスキーを二重に登録することはできない" do
    post options_credentials_path, as: :json
    # 本来はブラウザが excludeCredentials を見て作成を拒否する。
    # FakeClient はそれを再現しないので、登録済みと同じクレデンシャルIDを送り、サーバー側でも弾かれることを確認する
    credential = fake_client.create(challenge: response.parsed_body["challenge"])
    credential["id"] = credential["rawId"] = @alice.credentials.first.external_id
    post credentials_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_content
    assert_equal 1, @alice.credentials.count
  end

  test "初期名は User-Agent のブラウザ名で、同じ名前があれば番号を付ける" do
    add_passkey(headers: { "User-Agent" => CHROME_UA })
    add_passkey(headers: { "User-Agent" => CHROME_UA })
    add_passkey(headers: { "User-Agent" => "curl/8.0" })

    assert_equal [ "パスキー", "Chrome", "Chrome (2)", "パスキー (2)" ], @alice.credentials.order(:id).pluck(:nickname)
  end

  test "名前を変更できる" do
    credential = @alice.credentials.first
    patch credential_path(credential), params: { credential: { nickname: "仕事用のMac" } }
    assert_equal "仕事用のMac", credential.reload.nickname
  end

  test "ほかのユーザーのパスキーは変更できない" do
    bob_client = WebAuthn::FakeClient.new("http://localhost:3000")
    delete session_path
    register(email: "bob@example.com", client: bob_client)

    patch credential_path(@alice.credentials.first), params: { credential: { nickname: "乗っ取り" } }
    assert_response :not_found
  end

  test "最後の1つは削除できないが、2つ以上あれば削除できる" do
    delete credential_path(@alice.credentials.first)
    assert_equal 1, @alice.credentials.count

    add_passkey
    delete credential_path(@alice.credentials.first)
    assert_equal 1, @alice.credentials.count
    assert_not_equal "パスキー", @alice.credentials.first.nickname
  end

  test "登録できるのは15個まで" do
    14.times { add_passkey }
    assert_equal 15, @alice.credentials.count

    post options_credentials_path, as: :json
    assert_response :unprocessable_content
    assert_equal "パスキーは15個まで登録できます", response.parsed_body["error"]
  end

  test "追加したパスキーでもログインできる" do
    second_client = WebAuthn::FakeClient.new("http://localhost:3000")
    add_passkey(client: second_client)
    delete session_path

    log_in_with_passkey(@alice, client: second_client)
    assert_response :success
  end
end
