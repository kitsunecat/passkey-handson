# お題5：ログイン時のユーザー検証（UV）の設定を切り替える
class UserVerificationSettingsController < ApplicationController
  # browser：ブラウザ（認証器）に伝える user_verification
  # server_required：サーバー側でUVフラグを必須として検証するか
  MODES = {
    "preferred" => { browser: "preferred", server_required: false,
                     description: "できればユーザー検証をする。UVなしの認証でもログインできる" },
    "required" => { browser: "required", server_required: true,
                    description: "ユーザー検証が必須。ブラウザにも伝え、サーバーでもUVフラグを検証する" },
    "discouraged" => { browser: "discouraged", server_required: false,
                       description: "ユーザー検証を求めない。UVなしの認証を試す用" },
    "required_server_only" => { browser: "discouraged", server_required: true,
                                description: "ブラウザには discouraged と伝え、サーバーだけUVを必須にする。ユーザー検証をしない認証器を再現する" }
  }.freeze

  def update
    mode = params[:user_verification]
    return redirect_to(root_path, alert: "不正な値です") unless MODES.key?(mode)

    cookies.permanent[:user_verification] = mode
    redirect_to root_path, notice: "user_verification の設定を #{mode} にしました"
  end
end
