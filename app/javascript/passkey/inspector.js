// お題1：登録・ログインの各ステップでやり取りされたデータを画面に表示する
import { postJSON } from "passkey/encoding"

const section = document.getElementById("inspector")

export function resetInspector() {
  section.hidden = true
  document.getElementById("inspector-log").replaceChildren()
  document.getElementById("inspector-actions").hidden = true
}

export function inspect(title, data) {
  section.hidden = false
  const heading = document.createElement("h3")
  heading.textContent = title
  const pre = document.createElement("pre")
  pre.textContent = JSON.stringify(data, null, 2)
  document.getElementById("inspector-log").append(heading, pre)
  pre.scrollIntoView({ behavior: "smooth", block: "nearest" })
}

// 成功したら自動で遷移せず、「リプレイ」と「次へ進む」ボタンを出す
export function showResult(url, payload, result) {
  // ログイン時にCSRFトークンが変わるので、新しいトークンに差し替える
  document.querySelector('meta[name="csrf-token"]').content = result.csrf_token
  inspect("③ サーバーの検証結果", result.inspection)

  document.getElementById("inspector-actions").hidden = false
  document.getElementById("next-link").href = result.redirect_to
  document.getElementById("replay-button").onclick = async () => {
    try {
      // さっきと全く同じデータ（署名つき）をもう一度送ってみる
      await postJSON(url, payload)
      inspect("リプレイの結果", "成功してしまった！")
    } catch (error) {
      inspect("リプレイの結果：失敗（期待どおり）", { error: error.message, reason: error.reason })
    }
  }
}
