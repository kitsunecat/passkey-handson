Rails.application.routes.draw do
  root "home#show"

  # 新規登録（ユーザー作成＋パスキー登録）
  get  "signup",               to: "registrations#new",     as: :signup
  post "registration/options", to: "registrations#options", as: :registration_options
  post "registration",         to: "registrations#create",  as: :registration

  # パスキーでログイン／ログアウト
  post   "session/options", to: "sessions#options", as: :session_options
  post   "session",         to: "sessions#create",  as: :session
  delete "session",         to: "sessions#destroy"

  # お題4：パスキーの管理（追加登録・一覧・名前変更・削除）
  resources :credentials, only: [ :index, :create, :update, :destroy ] do
    post :options, on: :collection
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
