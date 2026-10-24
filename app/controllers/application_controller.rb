class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :user_verification_setting

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # お題5：ログイン時に求めるユーザー検証（UV）の設定。
  # 本来はサービスやテナントの設定だが、ハンズオンでは画面から切り替えやすいよう cookie に保存する
  def user_verification_setting
    UserVerificationSettingsController::MODES.key?(cookies[:user_verification]) ? cookies[:user_verification] : "preferred"
  end

  def log_in(user)
    reset_session # セッション固定攻撃を防ぐため、ログイン時にセッションIDを作り直す
    session[:user_id] = user.id
  end

  # パスキー関連のAPIで失敗したときの共通処理。
  # ユーザーにはわかりやすいメッセージを返し、原因はサーバーログに出す。
  def render_passkey_error(message, reason)
    Rails.logger.warn("[passkey] #{message} (#{reason})")
    render json: { error: message }, status: :unprocessable_content
  end
end
