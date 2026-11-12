# お題5：本人確認フラグ（UV）が false のパスキー認証のあとに、二要素目としてワンタイムコードを求める
#
# ハンズオンでは変更量を抑えるため、ワンタイムコードは固定値にしている。
# 本来は TOTP（認証アプリ）やメール・SMS で毎回違うコードを発行し、試行回数も制限する
class SecondFactorsController < ApplicationController
  VALID_CODE = "123456" # 通るコード。それ以外（例：000000）はすべて通らない
  EXPIRES_IN = 5.minutes

  before_action :require_pending_second_factor

  def new
  end

  def create
    unless params[:code].to_s == VALID_CODE
      flash.now[:alert] = "ワンタイムコードが違います"
      return render :new, status: :unprocessable_content
    end

    pending = session.delete(:pending_second_factor)
    log_in(User.find(pending["user_id"]))
    session[:last_login] = pending["last_login"].merge("second_factor" => true)
    redirect_to root_path, notice: "ログインしました"
  end

  private

  # パスキー認証（一要素目）を済ませてから、有効期限内に来た場合だけ受け付ける
  def require_pending_second_factor
    pending = session[:pending_second_factor]
    return if pending && Time.current.to_i < pending["expires_at"]

    session.delete(:pending_second_factor)
    redirect_to root_path, alert: "もう一度パスキーでログインしてください"
  end
end
