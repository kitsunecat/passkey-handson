// お題4：ログイン中のユーザーにパスキーを追加登録する（パスキーの管理画面）
// 流れは新規登録（registration.js）と同じ。違いは excludeCredentials に登録済みのパスキーが入っていること
import { base64urlToBuffer, bufferToBase64url, postJSON, showMessage } from "passkey/encoding"

document.getElementById("add-credential-button")?.addEventListener("click", async () => {
  showMessage("")

  try {
    // ① サーバーから登録オプションを受け取る
    const options = await postJSON("/credentials/options", {})
    options.challenge = base64urlToBuffer(options.challenge)
    options.user.id = base64urlToBuffer(options.user.id)
    // 登録済みのパスキーのクレデンシャルID。この中のどれかを持つ認証器では作成できない
    options.excludeCredentials = (options.excludeCredentials || []).map((c) => ({ ...c, id: base64urlToBuffer(c.id) }))

    // ② 認証器にパスキーの作成を依頼する
    const credential = await navigator.credentials.create({ publicKey: options })

    // ③ 公開鍵クレデンシャルをサーバーに送る
    const result = await postJSON("/credentials", {
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
    if (error.name === "InvalidStateError") {
      // excludeCredentials に含まれるパスキーを、この認証器がすでに持っている
      showMessage("この認証器にはすでにパスキーが登録されています")
    } else {
      showMessage(error.name === "NotAllowedError" ? "パスキーの作成がキャンセルされたか、この認証器では作成できませんでした" : error.message)
    }
  }
})
