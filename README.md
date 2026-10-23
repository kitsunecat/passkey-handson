# 🔑 Passkey Hands-on

パスキー（WebAuthn）で登録・ログインできる、最小構成の Rails アプリです。
Kaigi on Rails 2026「Railsのためのパスキー実践入門 〜マルチテナントSaaSでの意思決定〜」の振り返り勉強会で使います。

- Ruby 4.0 / Rails 8.1 / [webauthn-ruby](https://github.com/cedarcode/webauthn-ruby) 3.5 / SQLite
- フロントエンドは importmap ＋ 素の JavaScript（Node.js 不要）
- Docker だけで動きます。起動後はインターネット接続なしで登録・ログインできます

## 起動

```sh
git clone <このリポジトリ>
cd passkey-handson
docker compose up
```

ブラウザで **http://localhost:3000** を開きます（初回はイメージのビルドに数分かかります）。

テストの実行：

```sh
docker compose run --rm web bin/rails test
```

## 仮想認証器を使う（推奨）

Chrome の DevTools で、本物の認証器の代わりになる「仮想認証器」を使えます。

1. http://localhost:3000 を開いた状態で DevTools を開く
2. 右上の ︙ → More tools → **WebAuthn** を開く
3. 「Enable virtual authenticator environment」にチェック
4. 「Add」で認証器を追加する。お題によって以下を切り替えます
   - **Supports resident keys**：Discoverable Credential（ユーザーネームレスでログインできるパスキー）を保存できるか
   - **Supports user verification**：生体認証や PIN によるユーザー検証ができるか
5. 登録すると、WebAuthn パネルの「Credentials」に作られたパスキーが表示されます

> 仮想認証器はタブを閉じたりDevToolsを閉じたりすると消えます。消えた認証器のパスキーではログインできなくなるので、そのときは新規登録し直してください。

## 動きの流れ

| | ブラウザ（`app/javascript/passkey/`） | サーバー（`app/controllers/`） |
| --- | --- | --- |
| 登録 | `registration.js` | `RegistrationsController` |
| ログイン | `login.js` | `SessionsController` |

1. ブラウザがサーバーに **オプション**（チャレンジ、RP ID など）を要求する
2. ブラウザが `navigator.credentials.create` / `get` で **認証器** にパスキーの作成・署名を依頼する
3. ブラウザが結果をサーバーに送り、サーバーが **チャレンジ** と **署名** を検証する

サーバーに保存されるのは公開鍵だけです（`credentials.public_key`）。秘密鍵は認証器から出てきません。
WebAuthn の設定（RP ID など）は `config/initializers/webauthn.rb` にあります。

## お題

| | お題 | 講演との対応 |
| --- | --- | --- |
| 1 | [中身を覗く（全員）](docs/topics/01-inspect.md) | 登録・認証フロー、チャレンジ |
| 2 | [Conditional UI（オートフィル）](docs/topics/02-conditional-ui.md) | 意思決定3：UX設計 |
| 3 | [ユーザーネームファースト vs ユーザーネームレス](docs/topics/03-username-first.md) | 意思決定2：ユーザーの特定 |
| 4 | [複数パスキーと管理画面](docs/topics/04-multiple-passkeys.md) | 意思決定5・6：登録数とパスキーの識別 |
| 5 | [UVフラグと二要素認証](docs/topics/05-uv.md) | 意思決定4：パスキーと二要素認証 |

完成例は `answer/01-inspect` 〜 `answer/05-uv` ブランチにあります（いずれも `main` から分岐）。

```sh
git switch answer/02-conditional-ui
```

## 注意事項

- 必ず **http://localhost:3000** で開いてください。`127.0.0.1` や LAN の IP アドレスでは動きません（`127.0.0.1` は RP ID にできず、LAN の IP は安全な接続とみなされないため）
- ポート番号は変えないでください（`allowed_origins` と一致させているため）
- Codespaces などリモートの開発環境では動きません。手元の Docker で起動してください
- 仮想認証器の利用を推奨します。iCloud キーチェーンや Google パスワードマネージャーに保存すると、`localhost` 用のパスキーが同期されて残ります
- スマホで QR コードを読み取るログインはインターネット経由の中継を使うため、今回は対象外です

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| 「このパスキーは登録されていません」 | DB を消した、または別の環境で作ったパスキーです。新規登録し直すか、認証器側のパスキーを削除してください |
| パスキーの作成ができない | 仮想認証器の「Supports resident keys」がオフになっていないか確認してください（ベースのアプリは Discoverable Credential 必須です） |
| ボタンを押しても何も起きない | `http://localhost:3000` で開いているか、DevTools の Console にエラーが出ていないか確認してください |
| ポート 3000 が使用中 | ほかのアプリを止めてください（ポートは変更できません） |
| Linux で `Permission denied` が出る | ユーザーIDが1000以外の場合は `UID=$(id -u) GID=$(id -g) docker compose up` で起動してください |
| Gemfile を変更した | `docker compose build` でイメージを作り直してください |
| DB をまっさらにしたい | `docker compose run --rm web bin/rails db:reset` |
| サーバーのエラー原因を見たい | `docker compose logs web` の `[passkey]` で始まる行を確認してください |
