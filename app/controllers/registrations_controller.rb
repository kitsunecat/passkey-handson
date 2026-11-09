# パスキーの登録フロー
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① メールアドレスを送る  ───────▶  options：使い捨てのランダムな値（challenge）などの設定値を作る
#   ② navigator.credentials.create   （認証器が鍵ペアを作り、公開鍵だけを返す）
#   ③ パスキーのIDと公開鍵を送る ───▶  create：ランダムな値を確かめ、公開鍵をDBに保存
class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  # ① 登録用の設定値を作る
  def options
    user = User.new(email: params[:email].to_s.strip.downcase, webauthn_id: WebAuthn.generate_user_id)
    unless user.valid?
      return render_passkey_error(user.errors.full_messages.to_sentence, "invalid user")
    end

    options = WebAuthn::Credential.options_for_create(
      # user.id はユーザーを表すID（user handle）。認証器にパスキーと一緒に保存され、ログイン時に返ってくる
      user: { id: user.webauthn_id, name: user.email, display_name: user.email },
      authenticator_selection: {
        resident_key: "required",         # ユーザー情報ごと認証器に保存する（Discoverable Credential。メールアドレスなしでログインするため）
        user_verification: "preferred"    # 指紋・顔・PINなどによる本人確認を「できればする」
      }
    )

    # challenge：リクエストごとに作る使い捨てのランダムな値。③で確かめるのでセッションに保存しておく。
    # ユーザーはまだDBに保存しない（パスキーの作成に成功したら保存する）
    session[:registration] = { "email" => user.email, "webauthn_id" => user.webauthn_id, "challenge" => options.challenge }

    # ドメイン・サービス名・ユーザー情報・challenge などがJSONでブラウザに返る
    render json: options
  end

  # ③ 登録結果の検証と保存
  def create
    # 使い終わった challenge は成功・失敗にかかわらず削除する（同じデータを送り直す「リプレイ攻撃」を防ぐ）
    registration = session.delete(:registration)
    if registration.nil?
      return render_passkey_error("登録の有効期限が切れました。最初からやり直してください", "no registration challenge in session")
    end

    # ブラウザから届いたパスキーの情報（IDや公開鍵など）を読み込む
    webauthn_credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)

    # challenge・origin（ページの URL の `http://localhost:3000` の部分）・ドメインなどが正しいか確かめる。不正なら WebAuthn::Error が発生する
    webauthn_credential.verify(registration["challenge"])

    user = User.new(email: registration["email"], webauthn_id: registration["webauthn_id"])
    user.credentials.build(
      external_id: webauthn_credential.id,          # パスキーのID：ログイン時にどのパスキーかを特定する
      public_key: webauthn_credential.public_key,   # 公開鍵：ログイン時に署名を検証する（秘密鍵は届かない）
      sign_count: webauthn_credential.sign_count,
      aaguid: webauthn_credential.response.aaguid,  # 認証器の「種類」を表すID
      nickname: Credential.default_nickname(request.user_agent, [])
    )
    user.save!

    log_in(user)
    render json: { redirect_to: root_path }
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーの登録に失敗しました", "#{e.class}: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    render_passkey_error(e.record.errors.full_messages.to_sentence, "record invalid")
  end
end
