// パスキーの登録（新規登録画面）
import { base64urlToBuffer, bufferToBase64url, postJSON, showMessage } from "passkey/encoding"

const form = document.getElementById("registration-form")

form?.addEventListener("submit", async (event) => {
  event.preventDefault()
  showMessage("")

  try {
    // ① サーバーから登録オプション（チャレンジ、RP ID、ユーザー情報など）を受け取る
    const options = await postJSON("/registration/options", { email: form.email.value })

    // base64url 文字列で届いた値を、WebAuthn APIが求める ArrayBuffer に変換する
    options.challenge = base64urlToBuffer(options.challenge)
    options.user.id = base64urlToBuffer(options.user.id)
    options.excludeCredentials = (options.excludeCredentials || []).map((c) => ({ ...c, id: base64urlToBuffer(c.id) }))

    // ② 認証器にパスキーの作成を依頼する。
    //    ここで生体認証やPINによるユーザー確認が行われ、認証器の中で鍵ペアが作られる。
    //    戻ってくるのは公開鍵クレデンシャル（公開鍵など）で、秘密鍵は含まれない
    const credential = await navigator.credentials.create({ publicKey: options })

    // ③ 公開鍵クレデンシャルをサーバーに送り、検証・保存してもらう
    const result = await postJSON("/registration", {
      credential: {
        type: credential.type,
        id: credential.id,
        rawId: bufferToBase64url(credential.rawId),
        authenticatorAttachment: credential.authenticatorAttachment,
        clientExtensionResults: credential.getClientExtensionResults(),
        response: {
          clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
          attestationObject: bufferToBase64url(credential.response.attestationObject),
          transports: credential.response.getTransports?.() || []
        }
      }
    })

    window.location.href = result.redirect_to
  } catch (error) {
    console.error(error)
    showMessage(error.name === "NotAllowedError" ? "パスキーの作成がキャンセルされたか、この認証器では作成できませんでした" : error.message)
  }
})
