import type { Key } from "./vim-core.ts"
import {
  findScrollBox,
  number,
  selectContent,
  type RenderableLike,
  type RendererLike,
} from "./vim-chat.ts"

export type CopyApi = {
  renderer: RendererLike
  requestRender: () => void
}

export type CopyResult = "stay" | "exit" | "copy"

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}

export class CopyVisual {
  private scrollbox: RenderableLike | undefined
  private content: RenderableLike | undefined
  private anchorRow = 0
  private focusRow = 0
  private count = 0
  private pending = false
  constructor(private readonly api: CopyApi) {}

  private rowScreen(row: number) {
    return this.content ? number(this.content.y) + row : 0
  }

  private rowCount() {
    return Math.max(1, Math.floor(number(this.content?.height)))
  }

  private centerScreen() {
    if (!this.scrollbox) return 0
    return number(this.scrollbox.y) + Math.floor(Math.max(1, number(this.scrollbox.height)) / 2)
  }

  private recenter() {
    if (!this.scrollbox || !this.content) return
    const delta = this.rowScreen(this.focusRow) - this.centerScreen()
    if (delta !== 0) {
      this.scrollbox.scrollBy?.(delta)
      this.api.requestRender()
    }
  }

  private highlight() {
    if (!this.scrollbox || !this.content) return
    const first = Math.min(this.anchorRow, this.focusRow)
    const last = Math.max(this.anchorRow, this.focusRow)
    const top = this.rowScreen(first)
    const bottom = this.rowScreen(last)
    const left = number(this.scrollbox.x) + 1
    const right = number(this.scrollbox.x) + Math.max(1, number(this.scrollbox.width)) - 2
    selectContent(this.api.renderer, this.content, left, top, right, bottom)
  }

  enter() {
    this.scrollbox = findScrollBox(this.api.renderer.root)
    this.content = this.scrollbox?.content
    if (!this.scrollbox || !this.content) return false
    if (this.rowCount() <= 0) return false
    this.focusRow = clamp(this.centerScreen() - number(this.content.y), 0, this.rowCount() - 1)
    this.anchorRow = this.focusRow
    this.count = 0
    this.pending = false
    this.recenter()
    this.highlight()
    return true
  }

  cancel() {
    this.api.renderer.clearSelection?.()
    this.scrollbox = undefined
    this.content = undefined
    this.anchorRow = 0
    this.focusRow = 0
    this.count = 0
    this.pending = false
  }

  selectedText() {
    return this.api.renderer.getSelection?.()?.getSelectedText?.() ?? ""
  }

  handle(key: Key): CopyResult {
    if (key.name === "escape" || (key.name === "v" && !key.ctrl) || (key.ctrl && key.name === "c")) {
      this.cancel()
      return "exit"
    }
    if (key.name === "y") return "copy"
    if (key.name >= "1" && key.name <= "9") {
      this.count = this.count * 10 + Number(key.name)
      return "stay"
    }
    if (key.name === "0" && this.count > 0) {
      this.count = this.count * 10
      return "stay"
    }
    if (key.name === "g" && !key.shift) {
      if (this.pending) {
        this.pending = false
        this.count = 0
        this.focusRow = 0
        this.recenter()
        this.highlight()
      } else {
        this.pending = true
      }
      return "stay"
    }
    const count = this.count || 1
    if (key.name === "G" || (key.name === "g" && key.shift)) {
      this.count = 0
      this.pending = false
      this.focusRow = this.rowCount() - 1
      this.recenter()
      this.highlight()
      return "stay"
    }
    if (key.name === "o") {
      this.count = 0
      this.pending = false
      const anchor = this.anchorRow
      this.anchorRow = this.focusRow
      this.focusRow = anchor
      this.recenter()
      this.highlight()
      return "stay"
    }
    const ctrl = key.ctrl && (key.name === "d" || key.name === "u" || key.name === "f" || key.name === "b")
    if (key.name === "j" || key.name === "k" || ctrl) {
      const half = Math.max(1, Math.floor(Math.max(1, number(this.scrollbox?.height)) / 2))
      const full = Math.max(1, Math.floor(number(this.scrollbox?.height)))
      const step = ctrl ? (key.name === "d" || key.name === "u" ? half : full) : 1
      const direction = key.name === "j" || key.name === "d" || key.name === "f" ? 1 : -1
      this.focusRow = clamp(this.focusRow + direction * step * count, 0, this.rowCount() - 1)
      this.count = 0
      this.pending = false
      this.recenter()
      this.highlight()
      return "stay"
    }
    this.count = 0
    this.pending = false
    return "stay"
  }
}
