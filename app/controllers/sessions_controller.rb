# パスキーの認証（ログイン）フロー
#   - ユーザーネームレス：IDを入力せず、認証器に保存されたパスキーの候補から選ぶ
#   - ユーザーネームファースト（お題3）：先にメールアドレスを入力し、そのユーザーのパスキーだけで認証する
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① ボタンを押す          ───────▶  options：チャレンジ等を含むオプションを生成
#   ② navigator.credentials.get      （認証器が秘密鍵でチャレンジ等に署名する）
#   ③ 署名を送る            ───────▶  create：保存済みの公開鍵で署名を検証し、ログインさせる
class SessionsController < ApplicationController
  # ① 認証オプションの生成
  def options
    if params[:email].present?
      # ユーザーネームファースト：認証の前にユーザーを特定し、そのユーザーのパスキーだけを allowCredentials に指定する。
      # 認証器は、渡されたクレデンシャルIDに対応するパスキーで署名する（Discoverable でなくてもよい）
      #
      # 注意：「ユーザーが見つかりません」と返すと、メールアドレスが登録済みかどうかが第三者にわかってしまう（ユーザー列挙）。
      # 実際のサービスでは、見つからなくてもダミーのオプションを返すなどの対策を検討する
      user = User.find_by(email: params[:email].to_s.strip.downcase)
      return render_passkey_error("ユーザーが見つかりません", "unknown email") if user.nil?

      options = WebAuthn::Credential.options_for_get(
        allow: user.credentials.pluck(:external_id),
        user_verification: "preferred"
      )
      session[:authentication_user_id] = user.id
    else
      # ユーザーネームレス：allowCredentials を指定しない＝どのユーザーのパスキーでもよい。
      # ユーザーは認証器に保存されたパスキー（Discoverable Credential）の候補から選ぶ
      options = WebAuthn::Credential.options_for_get(user_verification: "preferred")
      session.delete(:authentication_user_id)
    end

    # ③で検証に使うので、チャレンジをセッションに保存しておく
    session[:authentication_challenge] = options.challenge

    render json: options
  end

  # ③ 署名の検証とログイン
  def create
    # 使い終わったチャレンジは成功・失敗にかかわらず削除する（同じデータの再送＝リプレイを防ぐ）
    challenge = session.delete(:authentication_challenge)
    expected_user_id = session.delete(:authentication_user_id)
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

    # ユーザーネームファーストのときは、①で特定したユーザーのパスキーであることを確認する
    if expected_user_id && credential.user_id != expected_user_id
      return render_passkey_error("パスキーの持ち主が一致しません", "credential does not belong to the user")
    end

    # 認証器から user handle が返ってきた場合は、パスキーの持ち主と一致するかも確認する。
    # Discoverable でないパスキーでは user handle が返らないことがある
    if webauthn_credential.user_handle && webauthn_credential.user_handle != credential.user.webauthn_id
      return render_passkey_error("パスキーの持ち主が一致しません", "user handle mismatch")
    end

    credential.update!(sign_count: webauthn_credential.sign_count)

    log_in(credential.user)
    render json: { redirect_to: root_path }
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーでのログインに失敗しました", "#{e.class}: #{e.message}")
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "ログアウトしました"
  end
end
