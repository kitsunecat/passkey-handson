# パスキーの認証（ログイン）フロー（ユーザーネームレス）
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① ボタンを押す          ───────▶  options：使い捨てのランダムな値（challenge）などの設定値を作る
#   ② navigator.credentials.get      （認証器が秘密鍵で challenge などに署名する）
#   ③ 署名を送る            ───────▶  create：保存済みの公開鍵で署名を検証し、ログインさせる
class SessionsController < ApplicationController
  # ① ログイン用の設定値を作る
  def options
    mode = UserVerificationSettingsController::MODES.fetch(user_verification_setting)
    options = WebAuthn::Credential.options_for_get(
      # allowCredentials を指定しない＝どのユーザーのパスキーでもよい（メールアドレスを入力しない＝ユーザーネームレス）。
      # ユーザーは認証器に保存されたパスキーの候補から選ぶ
      #
      # お題5：user_verification（ブラウザ・認証器へのお願い）
      #   preferred  ：できれば本人確認（指紋・顔・PINなど）をしてほしい
      #   required   ：本人確認をしてほしい（できない認証器は使えない）
      #   discouraged：本人確認は不要
      user_verification: mode[:browser]
    )

    # ③で確かめるので、challenge と本人確認（user_verification）の設定をセッションに保存しておく
    # （設定値を渡したあとで設定を変えられても、渡したときの設定で検証する）
    session[:authentication_challenge] = options.challenge
    session[:authentication_user_verification] = user_verification_setting

    render json: options
  end

  # ③ 署名の検証とログイン
  def create
    # 使い終わった challenge は成功・失敗にかかわらず削除する（同じデータを送り直す「リプレイ攻撃」を防ぐ）
    challenge = session.delete(:authentication_challenge)
    user_verification = session.delete(:authentication_user_verification)
    if challenge.nil?
      return render_passkey_error("ログインの有効期限が切れました。もう一度お試しください", "no authentication challenge in session")
    end

    webauthn_credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)

    # パスキーのIDから、登録済みのパスキー（公開鍵）とユーザーを特定する
    credential = Credential.find_by(external_id: webauthn_credential.id)
    if credential.nil?
      return render_passkey_error("このパスキーは登録されていません", "unknown credential id: #{webauthn_credential.id}")
    end

    # 保存済みの公開鍵で署名を検証し、challenge・origin（ページの URL の `http://localhost:3000` の部分）・ドメイン・使用回数（sign_count）も確かめる。
    # user_verification: true のときは、本人確認フラグ（UV）が立っていることも検証する。
    # 本人確認フラグは認証器の自己申告で、ブラウザに required を伝えるだけでは保証にならない。サーバー側でも必ず確認する
    webauthn_credential.verify(
      challenge,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      user_verification: UserVerificationSettingsController::MODES.fetch(user_verification)[:server_required]
    )

    # 認証器に保存されていたユーザーID（user handle）が、パスキーの持ち主と一致するかも確認する
    if webauthn_credential.user_handle != credential.user.webauthn_id
      return render_passkey_error("パスキーの持ち主が一致しません", "user handle mismatch")
    end

    credential.update!(sign_count: webauthn_credential.sign_count)

    log_in(credential.user)
    # 本人確認フラグ（UV）：認証器が「本人確認に成功した」と自己申告したかどうか
    session[:last_login] = {
      "user_verified" => webauthn_credential.response.authenticator_data.user_verified?,
      "user_verification" => user_verification
    }
    render json: { redirect_to: root_path }
  rescue WebAuthn::UserVerifiedVerificationError => e
    render_passkey_error("本人確認（指紋・顔・PINなど）が行われていないため、ログインできません", "#{e.class}: #{e.message}")
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーでのログインに失敗しました", "#{e.class}: #{e.message}")
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました"
  end
end
