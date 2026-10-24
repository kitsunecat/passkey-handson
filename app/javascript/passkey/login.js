// パスキーでログイン（トップページ）
import { base64urlToBuffer, bufferToBase64url, postJSON, showMessage } from "passkey/encoding"

// ユーザーネームレス：IDを入力せずに、認証器に保存されたパスキーの候補から選ぶ
document.getElementById("login-button")?.addEventListener("click", () => login())

// ユーザーネームファースト（お題3）：先にメールアドレスを入力する
const usernameFirstForm = document.getElementById("username-first-form")
usernameFirstForm?.addEventListener("submit", (event) => {
  event.preventDefault()
  login(usernameFirstForm.email.value)
})

async function login(email) {
  showMessage("")

  try {
    // ① サーバーから認証オプション（チャレンジ、RP IDなど）を受け取る。
    //    メールアドレスを送った場合は、そのユーザーのパスキーが allowCredentials に入って返ってくる
    const options = await postJSON("/session/options", email ? { email } : {})
    options.challenge = base64urlToBuffer(options.challenge)
    options.allowCredentials = (options.allowCredentials || []).map((c) => ({ ...c, id: base64urlToBuffer(c.id) }))

    // ② 認証器に署名を依頼する。
    //    allowCredentials が空なら、認証器に保存されたパスキーの候補から選ぶ（ユーザーネームレス）。
    //    allowCredentials があれば、そのクレデンシャルIDのパスキーで署名する（ユーザーネームファースト）。
    //    認証器はユーザー検証のあと、秘密鍵でチャレンジなどに署名する
    const credential = await navigator.credentials.get({ publicKey: options })

    // ③ 署名をサーバーに送り、保存済みの公開鍵で検証してもらう
    const result = await postJSON("/session", {
      credential: {
        type: credential.type,
        id: credential.id,
        rawId: bufferToBase64url(credential.rawId),
        authenticatorAttachment: credential.authenticatorAttachment,
        clientExtensionResults: credential.getClientExtensionResults(),
        response: {
          clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
          authenticatorData: bufferToBase64url(credential.response.authenticatorData),
          signature: bufferToBase64url(credential.response.signature),
          userHandle: credential.response.userHandle && bufferToBase64url(credential.response.userHandle)
        }
      }
    })

    window.location.href = result.redirect_to
  } catch (error) {
    console.error(error)
    showMessage(error.name === "NotAllowedError" ? "ログインがキャンセルされたか、使えるパスキーが見つかりませんでした" : error.message)
  }
}
