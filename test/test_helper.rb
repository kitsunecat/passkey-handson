ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webauthn/fake_client"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module PasskeyTestHelper
  # ブラウザと認証器の代わりをする偽クライアント
  def fake_client
    @fake_client ||= WebAuthn::FakeClient.new("http://localhost:3000")
  end

  # 新規登録の①〜③を通しで行う
  def register(email:, client: fake_client)
    post registration_options_path, params: { email: email }, as: :json
    challenge = response.parsed_body["challenge"]

    credential = client.create(challenge: challenge, user_verified: true)
    post registration_path, params: { credential: credential }, as: :json
    credential
  end

  # パスキーでログインの①〜③を通しで行う
  def log_in_with_passkey(user, client: fake_client)
    post session_options_path, as: :json
    challenge = response.parsed_body["challenge"]

    credential = client.get(challenge: challenge, user_verified: true, user_handle: WebAuthn.standard_encoder.decode(user.webauthn_id))
    post session_path, params: { credential: credential }, as: :json
    credential
  end
end

class ActionDispatch::IntegrationTest
  include PasskeyTestHelper
end
