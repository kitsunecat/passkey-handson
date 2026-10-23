class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def log_in(user)
    reset_session # セッション固定攻撃を防ぐため、ログイン時にセッションIDを作り直す
    session[:user_id] = user.id
  end

  # パスキー関連のAPIで失敗したときの共通処理。
  # ユーザーにはわかりやすいメッセージを返し、原因はサーバーログに出す。
  def render_passkey_error(message, reason)
    Rails.logger.warn("[passkey] #{message} (#{reason})")
    # お題1：原因（reason）も画面に表示して、何の検証で失敗したかを見えるようにする
    render json: { error: message, reason: reason }, status: :unprocessable_content
  end

  # お題1：ログイン・登録の成功時に返すJSON。
  # ログイン時に reset_session でCSRFトークンが変わるので、新しいトークンも返す（リプレイボタンで再送するため）
  def render_passkey_success(inspection)
    Rails.logger.info("[passkey] #{action_name}: #{inspection.to_json}")
    render json: { redirect_to: root_path, inspection: inspection, csrf_token: form_authenticity_token }
  end
end
