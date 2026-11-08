# 🔑 Passkey Hands-on

パスキー（WebAuthn）で登録・ログインできる、最小構成の Rails アプリです。
[Kaigi on Rails 2026「Railsのためのパスキー実践入門 〜マルチテナントSaaSでの意思決定〜」](https://kaigionrails.org/2026/talks/utakaha/)の振り返り勉強会で使います。

- Ruby 4.0 / Rails 8.1 / [webauthn-ruby](https://github.com/cedarcode/webauthn-ruby) 3.5 / SQLite
- フロントエンドは importmap ＋ 素の JavaScript（Node.js 不要）
- Docker だけで動きます。起動後はインターネット接続なしで登録・ログインできます

## 起動

```sh
git clone https://github.com/kitsunecat/passkey-handson.git
cd passkey-handson
docker compose up
```

ブラウザで **http://localhost:3000** を開きます（初回はイメージのビルドに数分かかります）。

テストの実行：

```sh
docker compose run --rm web bin/rails test
```

## 仮想認証器を使う（推奨）

**認証器** とは、パスキーを保管して、指紋・顔・PIN などで本人確認をする仕組みのことです（スマホ、PC、パスワードマネージャー、USB キーなど）。
Chrome の DevTools では、本物の認証器の代わりになる「仮想認証器」を使えます。

1. http://localhost:3000 を開いた状態で DevTools を開く
2. 右上の ︙ → More tools → **WebAuthn** を開く
3. 「Enable virtual authenticator environment」にチェック
4. 次の設定で「Add」を押して認証器を追加する（**初期値のままでは動きません**）

   | 項目 | 設定 |
   | --- | --- |
   | Protocol | ctap2 |
   | Transport | **internal** |
   | Supports resident keys | **オン** |
   | Supports large blob | オフ |
   | Supports user verification | **オン** |

   - **Supports resident keys**：メールアドレスを入力しなくてもログインできるパスキー（Discoverable Credential）を保存できるか
   - **Supports user verification**：指紋・顔・PIN などで本人確認ができるか
5. 登録すると、WebAuthn パネルの「Credentials」に作られたパスキーが表示されます

> Chrome では、「Supports user verification」がオフの認証器だと、ユーザーネームレスのログイン（「パスキーでログイン」ボタン）ができません。また Transport が usb の場合は、resident keys がオンでも本人確認なしではパスキーを作成できません。

> 仮想認証器はタブを閉じたりDevToolsを閉じたりすると消えます。消えた認証器のパスキーではログインできなくなるので、そのときは新規登録し直してください。

## お題

| | お題 | セッションとの対応 |
| --- | --- | --- |
| 1 | [中身を覗く（全員）](docs/topics/01-inspect.md) | パスキーとは、登録・ログインの流れ |
| 2 | [Conditional UI（オートフィル）](docs/topics/02-conditional-ui.md) | パスキーの UX 設計 |
| 3 | [ユーザーネームファースト vs ユーザーネームレス](docs/topics/03-username-first.md) | ログイン時にユーザーをどう特定するか |
| 4 | [複数パスキーと管理画面](docs/topics/04-multiple-passkeys.md) | パスキーをいくつ登録できるようにするか、登録したパスキーをどう識別するか |
| 5 | [本人確認フラグ（UV）と二要素認証](docs/topics/05-uv.md) | パスキーと二要素認証 |

完成例は `answer/01-inspect` 〜 `answer/05-uv` ブランチにあります（いずれも `main` から分岐）。

```sh
git switch answer/02-conditional-ui
```

## 注意事項

- 必ず **http://localhost:3000** で開いてください。`127.0.0.1` や LAN の IP アドレスでは動きません（パスキーは IP アドレスではなくドメイン名に紐づくため `127.0.0.1` では使えず、LAN の IP は安全な接続とみなされないため）
- ポート番号は変えないでください（パスキーを使ってよい URL として `http://localhost:3000` を設定しているため）
- Codespaces などリモートの開発環境では動きません。手元の Docker で起動してください
- 仮想認証器の利用を推奨します。iCloud キーチェーンや Google パスワードマネージャーに保存すると、`localhost` 用のパスキーが同期されて残ります
- スマホで QR コードを読み取るログインはインターネット経由の中継を使うため、今回は対象外です

