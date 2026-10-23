require "test_helper"

# お題2：Conditional UI
# オートフィルの表示はブラウザの機能なので、ここではHTMLとサーバー側の流れだけを確認する
class ConditionalUiTest < ActionDispatch::IntegrationTest
  test "ログイン画面の入力欄に autocomplete=\"username webauthn\" が付いている" do
    get root_path
    assert_select "input#username[autocomplete='username webauthn']"
    assert_select "#login-button"
  end

  test "Conditional UI のリクエスト中にボタンが押されても（オプションを2回取得しても）、最後のチャレンジでログインできる" do
    register(email: "alice@example.com")
    user = User.find_by!(email: "alice@example.com")
    delete session_path

    post session_options_path, as: :json # ページを開いたときの Conditional UI 用（中断される）
    log_in_with_passkey(user)             # ボタン方式
    assert_response :success
  end
end
