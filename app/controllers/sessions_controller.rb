# パスキーの認証（ログイン）フロー（ユーザーネームレス）
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① ボタンを押す          ───────▶  options：チャレンジ等を含むオプションを生成
#   ② navigator.credentials.get      （認証器が秘密鍵でチャレンジ等に署名する）
#   ③ 署名を送る            ───────▶  create：保存済みの公開鍵で署名を検証し、ログインさせる
class SessionsController < ApplicationController
  # ① 認証オプションの生成
  def options
    options = WebAuthn::Credential.options_for_get(
      # allowCredentials を指定しない＝どのユーザーのパスキーでもよい（ユーザーネームレス）。
      # ユーザーは認証器に保存されたパスキーの候補から選ぶ
      user_verification: "preferred"
    )

    # ③で検証に使うので、チャレンジをセッションに保存しておく
    session[:authentication_challenge] = options.challenge

    render json: options
  end

  # ③ 署名の検証とログイン
  def create
    # 使い終わったチャレンジは成功・失敗にかかわらず削除する（同じデータの再送＝リプレイを防ぐ）
    challenge = session.delete(:authentication_challenge)
    if challenge.nil?
      return render_passkey_error("ログインの有効期限が切れました。もう一度お試しください", "no authentication challenge in session")
    end

    webauthn_credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)

    # クレデンシャルIDから、登録済みのパスキー（公開鍵）とユーザーを特定する
    credential = Credential.find_by(external_id: webauthn_credential.id)
    if credential.nil?
      return render_passkey_error("このパスキーは登録されていません", "unknown credential id: #{webauthn_credential.id}")
    end

    # 保存済みの公開鍵で署名を検証し、チャレンジ・オリジン・RP ID・sign_count もチェックする
    webauthn_credential.verify(challenge, public_key: credential.public_key, sign_count: credential.sign_count)

    # 認証器に保存されていた user handle が、パスキーの持ち主と一致するかも確認する
    if webauthn_credential.user_handle != credential.user.webauthn_id
      return render_passkey_error("パスキーの持ち主が一致しません", "user handle mismatch")
    end

    previous_sign_count = credential.sign_count
    credential.update!(sign_count: webauthn_credential.sign_count)

    log_in(credential.user)
    render_passkey_success(
      challenge: challenge,
      credential_id: webauthn_credential.id,
      user_handle: webauthn_credential.user_handle,
      user: credential.user.email,
      user_present: webauthn_credential.response.authenticator_data.user_present?,
      user_verified: webauthn_credential.response.authenticator_data.user_verified?,
      sign_count: "#{previous_sign_count} → #{webauthn_credential.sign_count}",
      signature_verified_with: credential.public_key
    )
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーでのログインに失敗しました", "#{e.class}: #{e.message}")
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました"
  end
end
