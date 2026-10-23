# お題4：ログイン中のユーザーのパスキーを管理する
#   - 追加登録（上限15個）：登録フローと同じく options → navigator.credentials.create → create
#   - 一覧・名前変更・削除（最後の1つは削除できない）
class CredentialsController < ApplicationController
  before_action :require_login

  def index
    @credentials = current_user.credentials.order(:created_at)
  end

  # ① 追加登録のオプション生成
  def options
    if current_user.credentials.count >= Credential::MAX_PER_USER
      return render_passkey_error("パスキーは#{Credential::MAX_PER_USER}個まで登録できます", "limit reached")
    end

    options = WebAuthn::Credential.options_for_create(
      # 既存のパスキーと同じ user handle を使う（同じユーザーのパスキーとして認証器に保存される）
      user: { id: current_user.webauthn_id, name: current_user.email, display_name: current_user.email },
      # excludeCredentials：登録済みのパスキーを持つ認証器では、新しいパスキーを作らせない（同じ認証器での二重登録を防ぐ）
      exclude: current_user.credentials.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "preferred" }
    )
    session[:credential_creation_challenge] = options.challenge

    render json: options
  end

  # ③ 追加登録の検証と保存
  def create
    challenge = session.delete(:credential_creation_challenge)
    if challenge.nil?
      return render_passkey_error("登録の有効期限が切れました。最初からやり直してください", "no credential creation challenge in session")
    end

    webauthn_credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
    webauthn_credential.verify(challenge)

    current_user.credentials.create!(
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      aaguid: webauthn_credential.response.aaguid,
      nickname: Credential.default_nickname(request.user_agent, current_user.credentials.pluck(:nickname))
    )

    flash[:notice] = "パスキーを追加しました"
    render json: { redirect_to: credentials_path }
  rescue WebAuthn::Error => e
    render_passkey_error("パスキーの登録に失敗しました", "#{e.class}: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    render_passkey_error(e.record.errors.full_messages.to_sentence, "record invalid")
  end

  # 名前の変更
  def update
    credential = current_user.credentials.find(params[:id])
    if credential.update(params.expect(credential: [ :nickname ]))
      redirect_to credentials_path, notice: "名前を変更しました"
    else
      redirect_to credentials_path, alert: credential.errors.full_messages.to_sentence
    end
  end

  # 削除。最後の1つを消すとログインできなくなるので削除させない
  def destroy
    credential = current_user.credentials.find(params[:id])
    if current_user.credentials.count <= 1
      redirect_to credentials_path, alert: "最後のパスキーは削除できません"
    else
      credential.destroy!
      redirect_to credentials_path, notice: "「#{credential.nickname}」を削除しました"
    end
  end
end
