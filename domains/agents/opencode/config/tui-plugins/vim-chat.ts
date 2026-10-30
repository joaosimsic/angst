import type { Key } from "./vim-core.ts"

type MessageLike = {
  id: string
  role: string
}

type PartLike = {
  type?: string
  text?: string
  synthetic?: boolean
}

export type RenderableLike = {
  x: number
  y: number
  width: number
  height: number
  selectable?: boolean
  isDestroyed?: boolean
  content?: RenderableLike
  scrollBy?: (delta: number) => unknown
  getChildren?: () => readonly RenderableLike[]
  getChildrenCount?: () => number
  findDescendantById?: (id: string) => RenderableLike | undefined
}

export type RendererLike = {
  root: RenderableLike
  getSelection?: () => { getSelectedText?: () => string } | null
  getSelectionContainer?: () => RenderableLike | null
  startSelection?: (renderable: RenderableLike, x: number, y: number) => void
  updateSelection?: (
    renderable: RenderableLike | undefined,
    x: number,
    y: number,
    options?: { finishDragging?: boolean },
  ) => void
  clearSelection?: () => void
}

export type ChatApi = {
  sessionID: () => string | undefined
  renderer: RendererLike
  messages: (sessionID: string) => readonly MessageLike[]
  parts: (messageID: string) => readonly PartLike[]
  requestRender: () => void
}

type Turn = {
  messageIDs: string[]
  start: number
  end: number
}

type TurnBox = {
  messageIDs: string[]
  box: RenderableLike
}

export type ChatResult = "stay" | "exit" | "copy"

export function number(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0
}

function area(node: RenderableLike) {
  return Math.max(0, number(node.width)) * Math.max(0, number(node.height))
}

export function findScrollBox(root: RenderableLike | undefined) {
  let best: RenderableLike | undefined
  let bestArea = 0
  const seen = new Set<RenderableLike>()
  const visit = (node: RenderableLike | undefined) => {
    if (!node || seen.has(node) || node.isDestroyed) return
    seen.add(node)
    if (typeof node.scrollBy === "function" && node.content && area(node) > bestArea) {
      best = node
      bestArea = area(node)
    }
    for (const child of node.getChildren?.() ?? []) visit(child)
  }
  visit(root)
  return best
}

function messageText(parts: readonly PartLike[]) {
  return parts
    .filter((part) => part.type === "text" && !part.synthetic && typeof part.text === "string")
    .map((part) => part.text)
    .join("")
}

function findBox(root: RenderableLike, id: string) {
  return root.findDescendantById?.(id) ?? root.getChildren?.().find((child) => (child as any).id === id)
}

export function findSelectable(node: RenderableLike, x: number, y: number): RenderableLike | undefined {
  const children = node.getChildren?.() ?? []
  for (const child of children) {
    if (child.isDestroyed) continue
    const top = number(child.y)
    const bottom = top + Math.max(1, number(child.height)) - 1
    const left = number(child.x)
    const right = left + Math.max(1, number(child.width)) - 1
    if (y < top || y > bottom || x < left || x > right) continue
    if (child.selectable) return child
    const nested = findSelectable(child, x, y)
    if (nested) return nested
  }
}

export function findSelectableInRange(node: RenderableLike, top: number, bottom: number): RenderableLike | undefined {
  const children = node.getChildren?.() ?? []
  for (const child of children) {
    if (child.isDestroyed) continue
    const childTop = number(child.y)
    const childBottom = childTop + Math.max(1, number(child.height)) - 1
    if (childBottom < top || childTop > bottom) continue
    if (child.selectable) return child
    const nested = findSelectableInRange(child, top, bottom)
    if (nested) return nested
  }
}

export function selectContent(
  renderer: RendererLike,
  content: RenderableLike,
  left: number,
  top: number,
  right: number,
  bottom: number,
) {
  const selectable = content.selectable
  try {
    content.selectable = true
    renderer.clearSelection?.()
    renderer.startSelection?.(content, left, top)
  } finally {
    content.selectable = selectable
  }
  renderer.updateSelection?.(content, right, bottom, { finishDragging: true })
}

export class ChatVisual {
  private scrollbox: RenderableLike | undefined
  private content: RenderableLike | undefined
  private turns: Turn[] = []
  private anchor = 0
  private focus = 0
  private count = 0
  private pending = false

  constructor(private readonly api: ChatApi) {}

  private buildTurns() {
    const sessionID = this.api.sessionID()
    if (!sessionID || !this.scrollbox || !this.content) return []
    const messages = this.api.messages(sessionID)
    const boxes: TurnBox[] = []
    for (let index = 0; index < messages.length; index += 1) {
      const message = messages[index]
      if (!message || message.role !== "user") continue
      const box = findBox(this.content, message.id)
      if (!box || box.isDestroyed) continue
      const ids = [message.id]
      for (let next = index + 1; next < messages.length; next += 1) {
        const candidate = messages[next]
        if (!candidate || candidate.role === "user") break
        ids.push(candidate.id)
      }
      boxes.push({ messageIDs: ids, box })
    }
    const bottom = number(this.content.y) + Math.max(1, number(this.content.height)) - 1
    return boxes.map((entry, index): Turn => {
      const next = boxes[index + 1]
      return {
        messageIDs: entry.messageIDs,
        start: number(entry.box.y),
        end: next ? number(next.box.y) - 1 : bottom,
      }
    })
  }

  private refresh() {
    this.turns = this.buildTurns()
  }

  private initialIndex() {
    if (!this.scrollbox || this.turns.length === 0) return 0
    const top = number(this.scrollbox.y)
    const bottom = top + Math.max(1, number(this.scrollbox.height)) - 1
    const center = top + (bottom - top) / 2
    let best = 0
    let distance = Number.POSITIVE_INFINITY
    for (let index = 0; index < this.turns.length; index += 1) {
      const turn = this.turns[index]!
      if (center >= turn.start && center <= turn.end) return index
      const current = center < turn.start ? turn.start - center : center - turn.end
      if (current < distance) {
        distance = current
        best = index
      }
    }
    return best
  }

  private ensureVisible() {
    if (!this.scrollbox) return
    const turn = this.turns[this.focus]
    if (!turn) return
    const top = number(this.scrollbox.y)
    const bottom = top + Math.max(1, number(this.scrollbox.height)) - 1
    let delta = 0
    if (turn.start < top) delta = turn.start - top
    else if (turn.end > bottom) delta = turn.end - bottom
    if (delta !== 0) {
      this.scrollbox.scrollBy?.(delta)
      this.api.requestRender()
    }
  }

  private highlight() {
    if (!this.scrollbox || !this.content || !this.api.renderer) return
    this.refresh()
    const first = this.turns[Math.min(this.anchor, this.focus)]
    const last = this.turns[Math.max(this.anchor, this.focus)]
    if (!first || !last) return
    const top = Math.max(number(this.scrollbox.y), first.start)
    const bottom = Math.min(number(this.scrollbox.y) + Math.max(1, number(this.scrollbox.height)) - 1, last.end)
    if (bottom < top) return
    const left = number(this.scrollbox.x) + 1
    const right = number(this.scrollbox.x) + Math.max(1, number(this.scrollbox.width)) - 2
    selectContent(this.api.renderer, this.content, left, top, right, bottom)
  }

  enter() {
    if (!this.api.sessionID()) return false
    this.scrollbox = findScrollBox(this.api.renderer.root)
    this.content = this.scrollbox?.content
    if (!this.scrollbox || !this.content) return false
    this.refresh()
    if (this.turns.length === 0) return false
    this.anchor = this.initialIndex()
    this.focus = this.anchor
    this.count = 0
    this.pending = false
    this.ensureVisible()
    this.refresh()
    this.highlight()
    return true
  }

  cancel() {
    this.api.renderer.clearSelection?.()
    this.scrollbox = undefined
    this.content = undefined
    this.turns = []
    this.anchor = 0
    this.focus = 0
    this.count = 0
    this.pending = false
  }

  selectedText() {
    const first = Math.min(this.anchor, this.focus)
    const last = Math.max(this.anchor, this.focus)
    return this.turns
      .slice(first, last + 1)
      .flatMap((turn) => turn.messageIDs)
      .map((id) => messageText(this.api.parts(id)))
      .filter(Boolean)
      .join("\n\n")
  }

  handle(key: Key): ChatResult {
    if (key.name === "escape" || (key.name === "v" && !key.ctrl)) {
      this.cancel()
      return "exit"
    }
    if (key.ctrl && key.name === "c") {
      this.cancel()
      return "exit"
    }
    if (key.name === "y") {
      return "copy"
    }
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
        this.anchor = 0
        this.focus = 0
        this.ensureVisible()
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
      this.anchor = this.turns.length - 1
      this.focus = this.turns.length - 1
      this.ensureVisible()
      this.highlight()
      return "stay"
    }
    if (key.name === "o") {
      this.count = 0
      this.pending = false
      const anchor = this.anchor
      this.anchor = this.focus
      this.focus = anchor
      this.highlight()
      return "stay"
    }
    if (key.name === "j" || key.name === "k" || (key.ctrl && (key.name === "d" || key.name === "u"))) {
      const step = key.ctrl ? 5 : 1
      const direction = key.name === "j" || key.name === "d" ? 1 : -1
      this.focus = Math.max(0, Math.min(this.turns.length - 1, this.focus + direction * step * count))
      this.count = 0
      this.pending = false
      this.ensureVisible()
      this.highlight()
      return "stay"
    }
    this.count = 0
    this.pending = false
    return "stay"
  }
}
