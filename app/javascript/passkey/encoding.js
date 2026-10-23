// WebAuthn のAPIはバイナリ（ArrayBuffer）でやり取りするが、
// サーバーとはJSONでやり取りするので、base64url 文字列と相互に変換する。

export function base64urlToBuffer(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=")
  const binary = atob(padded)
  return Uint8Array.from(binary, (c) => c.charCodeAt(0)).buffer
}

export function bufferToBase64url(buffer) {
  const binary = String.fromCharCode(...new Uint8Array(buffer))
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

// RailsのCSRFトークンを付けてJSONをPOSTし、レスポンスのJSONを返す
export async function postJSON(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify(body)
  })
  const json = await response.json()
  if (!response.ok) throw new Error(json.error || "エラーが発生しました")
  return json
}

export function showMessage(text) {
  const element = document.getElementById("message")
  element.textContent = text
  element.hidden = !text
}
