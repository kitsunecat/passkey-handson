# パスキーの認証（ログイン）フロー（ユーザーネームレス）
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① ボタンを押す          ───────▶  options：チャレンジ等を含むオプションを生成
#   ② navigator.credentials.get      （認証器が秘密鍵でチャレンジ等に署名する）
#   ③ 署名を送る            ───────▶  create：保存済みの公開鍵で署名を検証し、ログインさせる
class SessionsController < ApplicationController
  # ① 認証オプションの生成
  def options
    mode = UserVerificationSettingsController::MODES.fetch(user_verification_setting)
    options = WebAuthn::Credential.options_for_get(
      # allowCredentials を指定しない＝どのユーザーのパスキーでもよい（ユーザーネームレス）。
      # ユーザーは認証器に保存されたパスキーの候補から選ぶ
      #
      # お題5：user_verification（ブラウザ・認証器へのお願い）
      #   preferred  ：できればユーザー検証（生体認証やPIN）をしてほしい
      #   required   ：ユーザー検証をしてほしい（できない認証器は使えない）
      #   discouraged：ユーザー検証は不要
      user_verification: mode[:browser]
    )

    # ③で検証に使うので、チャレンジとUVの設定をセッションに保存しておく
    # （オプション発行後に設定を変えられても、発行時の設定で検証する）
    session[:authentication_challenge] = options.challenge
    session[:authentication_user_verification] = user_verification_setting

    render json: options
  end

  # ③ 署名の検証とログイン
  def create
    # 使い終わったチャレンジは成功・失敗にかかわらず削除する（同じデータの再送＝リプレイを防ぐ）
    challenge = session.delete(:authentication_challenge)
    user_verification = session.delete(:authentication_user_verification)
    if challenge.nil?
      return render_passkey_error("ログインの有効期限が切れました。もう一度お試しください", "no authentication challenge in session")
    end

    webauthn_credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)

    # クレデンシャルIDから、登録済みのパスキー（公開鍵）とユーザーを特定する
    credential = Credential.find_by(external_id: webauthn_credential.id)
    if credential.nil?
      return render_passkey_error("このパスキーは登録されていません", "unknown credential id: #{webauthn_credential.id}")
    end

    # 保存済みの公開鍵で署名を検証し、チャレンジ・オリジン・RP ID・sign_count もチェックする。
    # user_verification: true のときは、UVフラグが立っていることも検証する。
    # UVフラグは認証器の自己申告で、ブラウザに required を伝えるだけでは保証にならない。サーバー側でも必ず確認する
    webauthn_credential.verify(
      challenge,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      user_verification: UserVerificationSettingsController::MODES.fetch(user_verification)[:server_required]
    )

    # 認証器に保存されていた user handle が、パスキーの持ち主と一致するかも確認する
    if webauthn_credential.user_handle != credential.user.webauthn_id
      return render_passkey_error("パスキーの持ち主が一致しません", "user handle mismatch")
    end

    credential.update!(sign_count: webauthn_credential.sign_count)

    log_in(credential.user)
    # UVフラグ：認証器が「ユーザー検証に成功した」と自己申告したかどうか
    session[:last_login] = {
      "user_verified" => webauthn_credential.response.authenticator_data.user_verified?,
      "user_verification" => user_verification
    }
    render json: { redirect_to: root_path }
  rescue WebAuthn::UserVerifiedVerificationError => e
    render_passkey_error("ユーザー検証（生体認証やPIN）が行われていないため、ログインできません", "#{e.class}: #{e.message}")
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーでのログインに失敗しました", "#{e.class}: #{e.message}")
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました"
  end
end
