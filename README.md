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

## 動きの流れ

| | ブラウザ（`app/javascript/passkey/`） | サーバー（`app/controllers/`） |
| --- | --- | --- |
| 登録 | `registration.js` | `RegistrationsController` |
| ログイン | `login.js` | `SessionsController` |

1. ブラウザがサーバーに、パスキーの作成やログインに必要な **設定値** を問い合わせる。中には、サーバーが毎回作る **使い捨てのランダムな値** や、パスキーを使えるドメイン（`localhost`）が入っている
2. ブラウザが `navigator.credentials.create` / `get` で **認証器** にパスキーの作成・署名を依頼する。ログインのときは、認証器がランダムな値などに秘密鍵で署名する
3. ブラウザが結果をサーバーに送り、サーバーが「ランダムな値が自分の作ったものか」を確かめる。ログインのときは「署名が正しいか」も確かめる

サーバーに保存されるのは公開鍵だけです（`credentials.public_key`）。秘密鍵は認証器から出てきません。
ランダムな値は1回使ったら捨てるので、通信を盗み見て同じデータを送り直しても（リプレイ攻撃）ログインできません。
WebAuthn の設定（パスキーを使えるドメインなど）は `config/initializers/webauthn.rb` にあります。

### コードや DevTools に出てくる用語

| 用語 | 意味 |
| --- | --- |
| `options`（オプション） | 登録用・ログイン用の設定値。サーバーが作ってブラウザに渡す |
| `challenge`（チャレンジ） | サーバーが毎回作る、使い捨てのランダムな値 |
| `rp`、RP ID | パスキーでログインさせる側のサービス（このアプリ）と、そのドメイン。RP は Relying Party の略 |
| `origin`（オリジン） | ページを開いている URL の `http://localhost:3000` の部分（パスは含まない） |
| credential（クレデンシャル） | 認証器に作られたパスキーそのもの。サーバーには ID と公開鍵だけが届く |
| ユーザーネームレス | メールアドレスを入力せず、認証器にあるパスキーを選ぶだけでログインする方式 |
| ユーザーネームファースト | 先にメールアドレスを入力し、そのユーザーのパスキーでログインする方式 |
| 本人確認フラグ（UV） | 認証器が指紋・顔・PIN などで本人確認をしたかどうかの印。UV は User Verified の略 |

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

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| 「このパスキーは登録されていません」 | DB を消した、または別の環境で作ったパスキーです。新規登録し直すか、認証器側のパスキーを削除してください |
| パスキーの作成ができない | 仮想認証器の設定（Transport が internal、resident keys と user verification がオン）を確認してください。ベースのアプリは、メールアドレスを入力せずにログインできるパスキー（Discoverable Credential）しか作れない設定です |
| 登録はできたがログインできない | 仮想認証器の「Supports user verification」がオフになっていないか確認してください |
| ボタンを押しても何も起きない | `http://localhost:3000` で開いているか、DevTools の Console にエラーが出ていないか確認してください |
| ポート 3000 が使用中 | ほかのアプリを止めてください（ポートは変更できません） |
| Linux で `Permission denied` が出る | ユーザーIDが1000以外の場合は `UID=$(id -u) GID=$(id -g) docker compose up` で起動してください |
| Gemfile を変更した | `docker compose build` でイメージを作り直してください |
| DB をまっさらにしたい | `docker compose run --rm web bin/rails db:reset` |
| サーバーのエラー原因を見たい | `docker compose logs web` の `[passkey]` で始まる行を確認してください |
