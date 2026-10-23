// パスキーでログイン（トップページ）
import { base64urlToBuffer, bufferToBase64url, postJSON, showMessage } from "passkey/encoding"
import { inspect, resetInspector, showResult } from "passkey/inspector"

const button = document.getElementById("login-button")

button?.addEventListener("click", async () => {
  showMessage("")
  resetInspector()

  try {
    // ① サーバーから認証オプション（チャレンジ、RP IDなど）を受け取る
    const options = await postJSON("/session/options", {})
    inspect("① サーバーが生成したオプション", options)
    options.challenge = base64urlToBuffer(options.challenge)
    options.allowCredentials = (options.allowCredentials || []).map((c) => ({ ...c, id: base64urlToBuffer(c.id) }))

    // ② 認証器に署名を依頼する。
    //    allowCredentials が空なので、認証器に保存されたパスキーの候補から選ぶ（ユーザーネームレス）。
    //    認証器はユーザー検証のあと、秘密鍵でチャレンジなどに署名する
    const credential = await navigator.credentials.get({ publicKey: options })

    // ③ 署名をサーバーに送り、保存済みの公開鍵で検証してもらう
    const payload = {
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
    }
    inspect("② ブラウザがサーバーに送るデータ", payload)
    // clientDataJSON の中身：チャレンジとオリジンが入っていて、これも署名・検証の対象になる
    inspect("②' clientDataJSON をデコードした中身", JSON.parse(new TextDecoder().decode(credential.response.clientDataJSON)))

    const result = await postJSON("/session", payload)
    showResult("/session", payload, result)
  } catch (error) {
    console.error(error)
    showMessage(error.name === "NotAllowedError" ? "ログインがキャンセルされたか、使えるパスキーが見つかりませんでした" : error.message)
  }
})
