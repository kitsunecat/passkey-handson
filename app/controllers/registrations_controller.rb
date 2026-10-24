# パスキーの登録フロー
#
#   ブラウザ                         サーバー（このコントローラー）
#   ① メールアドレスを送る  ───────▶  options：チャレンジ等を含むオプションを生成
#   ② navigator.credentials.create   （認証器が鍵ペアを作り、公開鍵だけを返す）
#   ③ 公開鍵クレデンシャルを送る ───▶  create：チャレンジを検証し、公開鍵をDBに保存
class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if current_user
  end

  # ① 登録オプションの生成
  def options
    user = User.new(email: params[:email].to_s.strip.downcase, webauthn_id: WebAuthn.generate_user_id)
    unless user.valid?
      return render_passkey_error(user.errors.full_messages.to_sentence, "invalid user")
    end

    options = WebAuthn::Credential.options_for_create(
      # user.id は WebAuthn の user handle。認証器にパスキーと一緒に保存され、ログイン時に返ってくる
      user: { id: user.webauthn_id, name: user.email, display_name: user.email },
      authenticator_selection: {
        resident_key: "required",         # Discoverable Credential にする（ユーザーネームレスでログインするため）
        user_verification: "preferred"    # 生体認証やPINによるユーザー検証を「できればする」
      }
    )

    # チャレンジ：リクエストごとに生成されるランダムな値。③で検証に使うのでセッションに保存しておく。
    # ユーザーはまだDBに保存しない（パスキーの作成に成功したら保存する）
    session[:registration] = { "email" => user.email, "webauthn_id" => user.webauthn_id, "challenge" => options.challenge }

    # RP ID・RP名・ユーザー情報・チャレンジなどがJSONでブラウザに返る
    render json: options
  end

  # ③ 登録結果の検証と保存
  def create
    # 使い終わったチャレンジは成功・失敗にかかわらず削除する（同じデータの再送＝リプレイを防ぐ）
    registration = session.delete(:registration)
    if registration.nil?
      return render_passkey_error("登録の有効期限が切れました。最初からやり直してください", "no registration challenge in session")
    end

    # ブラウザから届いた公開鍵クレデンシャルを読み込む
    webauthn_credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)

    # チャレンジ・オリジン・RP IDなどを検証する。不正なら WebAuthn::Error が発生する
    webauthn_credential.verify(registration["challenge"])

    user = User.new(email: registration["email"], webauthn_id: registration["webauthn_id"])
    user.credentials.build(
      external_id: webauthn_credential.id,          # クレデンシャルID：ログイン時にどのパスキーかを特定する
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
