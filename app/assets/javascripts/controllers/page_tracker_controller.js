import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: { type: String, default: "" } }
  connect() {
    this.lastTracked = null
    this.boundLoad = () => this.trackCurrent()
    this.boundHash = () => this.trackCurrent()

    document.addEventListener("turbo:load", this.boundLoad)
    window.addEventListener("hashchange", this.boundHash)

    // Cover initial load if turbo:load already fired before connect()
    this.trackCurrent()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.boundLoad)
    window.removeEventListener("hashchange", this.boundHash)
  }

  trackCurrent() {
    const path = window.location.pathname + window.location.hash
    if (path === this.lastTracked) return
    this.lastTracked = path
    this.track(path)
  }

  track(path) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const traceId = document.querySelector('meta[name="trace-id"]')?.content
    const url = this.urlValue || document.querySelector('meta[name="trackguard-url"]')?.content
    const ref = new URLSearchParams(window.location.search).get("ref")
    fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token || "" },
      body: JSON.stringify({ path, trace_id: traceId, ref })
    })
  }
}
