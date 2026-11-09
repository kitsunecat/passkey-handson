# お題5：ログイン時の本人確認（UV）の設定を切り替える
class UserVerificationSettingsController < ApplicationController
  # キー：ブラウザ（認証器）に伝える user_verification の値。label：画面に出す「本人確認を求めるか」の選択肢
  # server_required：サーバー側で本人確認フラグ（UV）が true であることを必須として検証するか
  MODES = {
    "required" => { label: "必ず求める", server_required: true,
                    description: "ブラウザ（認証器）に本人確認をお願いし、サーバーでも本人確認フラグが true かを検証する" },
    "preferred" => { label: "できれば求める", server_required: false,
                     description: "ブラウザ（認証器）にできれば本人確認をお願いする。本人確認フラグが false でもログインを拒否しない" },
    "discouraged" => { label: "求めない", server_required: false,
                       description: "ブラウザ（認証器）に本人確認は不要と伝える。本人確認フラグが false でもログインを拒否しない" }
  }.freeze

  def update
    mode = params[:user_verification]
    return redirect_to(root_path, alert: "不正な値です") unless MODES.key?(mode)

    cookies.permanent[:user_verification] = mode
    cookies.permanent[:simulate_no_user_verification] = params[:simulate_no_user_verification] == "1" ? "1" : "0"
    redirect_to root_path, notice: "設定を変更しました（本人確認を求めるか：#{MODES[mode][:label]}、本人確認しない認証器を再現：#{simulate_no_user_verification? ? 'オン' : 'オフ'}）"
  end
end
