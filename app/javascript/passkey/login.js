// パスキーでログイン（トップページ）
//   - Conditional UI：入力欄のオートフィルにパスキーを候補として出す
//   - ボタン方式：「パスキーでログイン」ボタンを押したときに認証を始める
import { base64urlToBuffer, bufferToBase64url, postJSON, showMessage } from "passkey/encoding"

const button = document.getElementById("login-button")
const usernameInput = document.getElementById("username")

// 発展：パスキーでログインしたことを記録する localStorage のキー
const PASSKEY_USED_KEY = "passkeyUsed"

// 待機中の Conditional UI のリクエストを中断するためのもの
let conditionalAbort = null

async function authenticate({ mediation, signal } = {}) {
  // ① サーバーから認証オプション（チャレンジ、RP IDなど）を受け取る
  const options = await postJSON("/session/options", {})
  options.challenge = base64urlToBuffer(options.challenge)
  options.allowCredentials = (options.allowCredentials || []).map((c) => ({ ...c, id: base64urlToBuffer(c.id) }))

  // 発展：以前パスキーでログインした人にだけ、入力欄にフォーカスしてすぐ候補を出す
  if (mediation === "conditional" && passkeyUsedBefore()) usernameInput.focus()

  // ② 認証器に署名を依頼する。
  //    mediation: "conditional" のときは、ユーザーがオートフィルの候補からパスキーを選ぶまで待機する
  const credential = await navigator.credentials.get({ publicKey: options, mediation, signal })

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

  rememberPasskeyUsed()
  window.location.href = result.redirect_to
}

// Conditional UI を開始する。ブラウザが対応していなければ何もしない（ボタン方式だけになる）
async function startConditionalUI() {
  if (!usernameInput) return
  if (!(await window.PublicKeyCredential?.isConditionalMediationAvailable?.())) return

  conditionalAbort = new AbortController()
  try {
    await authenticate({ mediation: "conditional", signal: conditionalAbort.signal })
  } catch (error) {
    if (error.name === "AbortError") return // ボタンが押されて中断した場合
    handleError(error)
  }
}

// ボタン方式。待機中の Conditional UI を中断してから、モーダルで認証を始める
async function startModalLogin() {
  conditionalAbort?.abort()
  showMessage("")

  try {
    await authenticate()
  } catch (error) {
    handleError(error)
    startConditionalUI() // 失敗したら、オートフィルでも選べる状態に戻す
  }
}

function handleError(error) {
  console.error(error)
  showMessage(error.name === "NotAllowedError" ? "ログインがキャンセルされたか、使えるパスキーが見つかりませんでした" : error.message)
}

function passkeyUsedBefore() {
  try { return localStorage.getItem(PASSKEY_USED_KEY) === "true" } catch { return false }
}

function rememberPasskeyUsed() {
  try { localStorage.setItem(PASSKEY_USED_KEY, "true") } catch {}
}

button?.addEventListener("click", startModalLogin)
document.getElementById("login-form")?.addEventListener("submit", (event) => {
  event.preventDefault()
  startModalLogin()
})
startConditionalUI()
