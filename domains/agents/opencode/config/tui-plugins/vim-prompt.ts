import type { Action, Mode, Motion, Operator, TextObject } from "./vim-core.ts"

type Cursor = { row: number; col: number }

export type PromptTarget = {
  plainText: string
  cursorOffset: number
  isDestroyed?: boolean
  logicalCursor?: Cursor
  getSelectedText?: () => string
  getSelection?: () => { start: number; end: number } | null
  setSelection?: (start: number, end: number) => void
  setSelectionInclusive?: (start: number, end: number) => void
  clearSelection?: () => boolean | void
  deleteSelection?: () => boolean
  insertText?: (text: string) => void
  deleteChar?: () => boolean
  deleteCharBackward?: () => boolean
  deleteLine?: () => boolean
  deleteToLineEnd?: () => boolean
  moveCursorLeft?: (options?: { select?: boolean }) => boolean
  moveCursorRight?: (options?: { select?: boolean }) => boolean
  moveCursorUp?: (options?: { select?: boolean }) => boolean
  moveCursorDown?: (options?: { select?: boolean }) => boolean
  moveWordForward?: (options?: { select?: boolean }) => boolean
  moveWordBackward?: (options?: { select?: boolean }) => boolean
  gotoLineStart?: () => boolean | void
  gotoLineHome?: (options?: { select?: boolean }) => boolean
  gotoLineEnd?: (options?: { select?: boolean }) => boolean
  gotoLineTextEnd?: (options?: { select?: boolean }) => boolean | void
  gotoBufferHome?: (options?: { select?: boolean }) => boolean
  gotoBufferEnd?: (options?: { select?: boolean }) => boolean
  undo?: () => boolean
  redo?: () => boolean
}

type SessionRunner = (command: string) => boolean

export type PromptResult = {
  mode?: Mode
  handled: boolean
}

function isFunction(value: unknown): value is (...args: any[]) => any {
  return typeof value === "function"
}

export function getPromptTarget(editor: unknown): PromptTarget | undefined {
  if (!editor || typeof editor !== "object") return
  const value = editor as Record<string, unknown>
  if (value.isDestroyed === true) return
  if (typeof value.plainText !== "string") return
  if (typeof value.cursorOffset !== "number") return
  if (!isFunction(value.setSelection)) return
  if (!isFunction(value.getSelectedText)) return
  if (!isFunction(value.insertText)) return
  return editor as PromptTarget
}

function displayWidth(text: string) {
  const bun = (globalThis as any).Bun as { stringWidth?: (input: string) => number } | undefined
  if (bun?.stringWidth) {
    try {
      return bun.stringWidth(text)
    } catch {}
  }
  return text.length
}

function textWidth(point: string) {
  if (point === "\n") return 1
  return Math.max(0, displayWidth(point))
}

function displayToIndex(text: string, offset: number) {
  if (offset <= 0) return 0
  let width = 0
  let index = 0
  for (const point of Array.from(text)) {
    const next = width + textWidth(point)
    if (next > offset) return index
    width = next
    index += point.length
  }
  return text.length
}

function indexToDisplay(text: string, index: number) {
  let width = 0
  let position = 0
  for (const point of Array.from(text)) {
    if (position >= index) return width
    position += point.length
    width += textWidth(point)
  }
  return width
}

function lineStartIndex(text: string, index: number) {
  if (index <= 0) return 0
  const previous = text.lastIndexOf("\n", index - 1)
  return previous + 1
}

function lineEndIndex(text: string, index: number) {
  const next = text.indexOf("\n", index)
  return next === -1 ? text.length : next
}

function lineRange(text: string, offset: number, count: number, includeNewline: boolean) {
  const index = displayToIndex(text, offset)
  const start = lineStartIndex(text, index)
  let position = start
  let end = text.length
  const total = Math.max(1, count)
  for (let line = 0; line < total; line += 1) {
    const next = text.indexOf("\n", position)
    if (next === -1) {
      end = text.length
      break
    }
    end = line === total - 1 && !includeNewline ? next : next + 1
    position = next + 1
  }
  return { start: indexToDisplay(text, start), end: indexToDisplay(text, end) }
}

function linewiseSelection(text: string, offset: number, count: number, includeNewline: boolean) {
  const range = lineRange(text, offset, count, includeNewline)
  return { start: range.start, end: range.end, cursor: range.start }
}

function isWord(char: string) {
  return /[A-Za-z0-9_]/.test(char)
}

function wordObject(text: string, offset: number, around: boolean): { start: number; end: number } {
  const index = displayToIndex(text, offset)
  const point = index < text.length ? text[index] : ""
  if (!point) {
    const start = Math.max(0, index - 1)
    return { start: start, end: index }
  }
  const word = isWord(point)
  let start = index
  let end = index + point.length
  if (word) {
    while (start > 0 && isWord(text[start - 1]!)) start -= 1
    while (end < text.length && isWord(text[end]!)) end += 1
  } else {
    while (start > 0 && !isWord(text[start - 1]!) && text[start - 1] !== "\n" && text[start - 1] !== " ") start -= 1
    while (end < text.length && !isWord(text[end]!) && text[end] !== "\n" && text[end] !== " ") end += 1
  }
  if (around) {
    const lineEnd = lineEndIndex(text, end)
    let next = end
    while (next < lineEnd && text[next] === " ") next += 1
    if (next > end) end = next
    else {
      let previous = start
      while (previous > 0 && text[previous - 1] === " ") previous -= 1
      start = previous
    }
  }
  return { start: indexToDisplay(text, start), end: indexToDisplay(text, end) }
}

function quoteObject(text: string, offset: number, quote: string, around: boolean) {
  const index = displayToIndex(text, offset)
  const start = lineStartIndex(text, index)
  const end = lineEndIndex(text, index)
  let left = -1
  let right = -1
  for (let i = index; i >= start; i -= 1) {
    if (text[i] === quote) {
      left = i
      break
    }
  }
  if (left === -1) {
    for (let i = start; i < end; i += 1) {
      if (text[i] === quote) {
        left = i
        break
      }
    }
  }
  if (left === -1) return
  for (let i = Math.max(index, left + 1); i < end; i += 1) {
    if (text[i] === quote) {
      right = i
      break
    }
  }
  if (right === -1) return
  const from = around ? left : left + 1
  const to = around ? right + 1 : right
  return { start: indexToDisplay(text, from), end: indexToDisplay(text, to) }
}

function bracketObject(text: string, offset: number, open: string, close: string, around: boolean) {
  const index = displayToIndex(text, offset)
  let left = -1
  let right = -1
  for (let i = index; i >= 0; i -= 1) {
    if (text[i] === open) {
      left = i
      break
    }
  }
  if (left === -1) return
  let depth = 0
  for (let i = left; i < text.length; i += 1) {
    if (text[i] === open) depth += 1
    if (text[i] === close) {
      depth -= 1
      if (depth === 0) {
        right = i
        break
      }
    }
  }
  if (right === -1) return
  const from = around ? left : left + 1
  const to = around ? right + 1 : right
  return { start: indexToDisplay(text, from), end: indexToDisplay(text, to) }
}

function textObjectRange(text: string, offset: number, object: TextObject) {
  if (object.object === "w" || object.object === "W") return wordObject(text, offset, object.around)
  if (object.object === "b" || object.object === "B") return bracketObject(text, offset, "(", ")", object.around)
  if (object.object === "(" || object.object === ")") return bracketObject(text, offset, "(", ")", object.around)
  if (object.object === "[" || object.object === "]") return bracketObject(text, offset, "[", "]", object.around)
  if (object.object === "{" || object.object === "}") return bracketObject(text, offset, "{", "}", object.around)
  if (object.object === '"' || object.object === "'" || object.object === "`") {
    return quoteObject(text, offset, object.object, object.around)
  }
}

function setCursor(target: PromptTarget, offset: number) {
  try {
    target.cursorOffset = offset
  } catch {}
}

function selectRange(target: PromptTarget, start: number, end: number) {
  if (!target.setSelection) return
  if (start === end) {
    target.clearSelection?.()
    setCursor(target, start)
    return
  }
  target.setSelection(start, end)
}

function moveOnce(target: PromptTarget, motion: Motion): boolean {
  switch (motion) {
    case "left":
      return target.moveCursorLeft?.() ?? false
    case "right":
      return target.moveCursorRight?.() ?? false
    case "up":
      return target.moveCursorUp?.() ?? false
    case "down":
      return target.moveCursorDown?.() ?? false
    case "wordForward":
    case "WORDForward":
      return target.moveWordForward?.() ?? false
    case "wordBackward":
    case "WORDBackward":
      return target.moveWordBackward?.() ?? false
    case "wordEnd":
    case "WORDEnd":
      if (!target.moveWordForward?.()) return false
      target.moveCursorLeft?.()
      return true
    case "lineStart":
      if (target.gotoLineStart) {
        target.gotoLineStart()
        return true
      }
      return target.gotoLineHome?.() ?? false
    case "lineFirstNonBlank":
      if (target.gotoLineStart) target.gotoLineStart()
      else if (!target.gotoLineHome?.()) return false
      if (target.plainText[target.cursorOffset] !== " ") return true
      while (target.plainText[target.cursorOffset] === " ") target.moveCursorRight?.()
      return true
    case "lineEnd":
      if (target.gotoLineTextEnd) {
        target.gotoLineTextEnd()
        return true
      }
      return target.gotoLineEnd?.() ?? false
    case "bufferStart":
      return target.gotoBufferHome?.() ?? false
    case "bufferEnd":
      return target.gotoBufferEnd?.() ?? false
    default:
      return false
  }
}

function isSessionMotion(motion: Motion) {
  return (
    motion === "nextMessage" ||
    motion === "previousMessage" ||
    motion === "lineDown" ||
    motion === "lineUp" ||
    motion === "halfPageDown" ||
    motion === "halfPageUp" ||
    motion === "pageDown" ||
    motion === "pageUp"
  )
}

function sessionCommand(motion: Motion) {
  switch (motion) {
    case "nextMessage":
      return "session.message.next"
    case "previousMessage":
      return "session.message.previous"
    case "lineDown":
      return "session.line.down"
    case "lineUp":
      return "session.line.up"
    case "halfPageDown":
      return "session.half.page.down"
    case "halfPageUp":
      return "session.half.page.up"
    case "pageDown":
      return "session.page.down"
    case "pageUp":
      return "session.page.up"
  }
}

function repeat(count: number, fn: () => boolean) {
  let handled = false
  for (let index = 0; index < count; index += 1) {
    if (!fn()) break
    handled = true
  }
  return handled
}

export class VimPrompt {
  private register = ""
  private registerLinewise = false
  private anchor: number | undefined
  private visualLine = false

  constructor(
    private readonly target: () => PromptTarget | undefined,
    private readonly session: SessionRunner,
    private readonly dispatch: (command: string) => boolean,
  ) {}

  reset() {
    this.register = ""
    this.registerLinewise = false
    this.anchor = undefined
    this.visualLine = false
  }

  clearSelection() {
    const prompt = this.target()
    prompt?.clearSelection?.()
    this.anchor = undefined
    this.visualLine = false
  }

  private prompt() {
    return this.target()
  }

  private moveMotion(motion: Motion, count: number, select: boolean) {
    if (motion === "nextMessage" || motion === "previousMessage" || isSessionMotion(motion)) {
      return this.session(sessionCommand(motion) ?? "")
    }
    const prompt = this.prompt()
    if (!prompt) {
      if (motion === "down" || motion === "up") {
        return this.session(motion === "down" ? "session.line.down" : "session.line.up")
      }
      if (motion === "bufferStart" || motion === "bufferEnd") {
        return this.session(motion === "bufferStart" ? "session.first" : "session.last")
      }
      return false
    }
    const text = prompt.plainText
    const hasText = text.length > 0
    const from = select ? (this.anchor ?? prompt.cursorOffset) : prompt.cursorOffset
    if (!hasText && (motion === "up" || motion === "down")) {
      return this.session(motion === "down" ? "session.line.down" : "session.line.up")
    }
    if (!hasText && (motion === "bufferStart" || motion === "bufferEnd")) {
      return this.session(motion === "bufferStart" ? "session.first" : "session.last")
    }
    const handled = repeat(count, () => moveOnce(prompt, motion))
    if (!handled) return false
    if (select) {
      if (this.visualLine) this.selectVisualLines()
      else selectRange(prompt, Math.min(from, prompt.cursorOffset), Math.max(from, prompt.cursorOffset))
    } else {
      prompt.clearSelection?.()
    }
    return true
  }

  private selectVisualLines() {
    const prompt = this.prompt()
    if (!prompt || this.anchor === undefined) return
    const anchorIndex = displayToIndex(prompt.plainText, this.anchor)
    const cursorIndex = displayToIndex(prompt.plainText, prompt.cursorOffset)
    const first = Math.min(lineStartIndex(prompt.plainText, anchorIndex), lineStartIndex(prompt.plainText, cursorIndex))
    const last = Math.max(lineEndIndex(prompt.plainText, anchorIndex), lineEndIndex(prompt.plainText, cursorIndex))
    const end = last < prompt.plainText.length ? last + 1 : last
    selectRange(prompt, indexToDisplay(prompt.plainText, first), indexToDisplay(prompt.plainText, end))
    this.anchor = indexToDisplay(prompt.plainText, first)
  }

  private selectTextObject(prompt: PromptTarget, object: TextObject) {
    const range = textObjectRange(prompt.plainText, prompt.cursorOffset, object)
    if (!range) return false
    selectRange(prompt, range.start, range.end)
    return true
  }

  private yank(text: string, linewise: boolean) {
    this.register = text
    this.registerLinewise = linewise
  }

  private selected(prompt: PromptTarget) {
    if (prompt.getSelectedText) {
      const value = prompt.getSelectedText()
      if (value) return value
    }
    if (prompt.getSelection) {
      const range = prompt.getSelection()
      if (range) {
        const text = prompt.plainText
        return text.slice(displayToIndex(text, range.start), displayToIndex(text, range.end))
      }
    }
    return ""
  }

  private executeOperator(action: Extract<Action, { type: "operator" }>): PromptResult {
    const prompt = this.prompt()
    if (!prompt) return { handled: false }
    const start = prompt.cursorOffset
    let linewise = action.line === true
    let selected = false
    if (action.textObject) {
      selected = this.selectTextObject(prompt, action.textObject)
    } else if (linewise) {
      const range = linewiseSelection(prompt.plainText, start, action.count, action.operator !== "change")
      selectRange(prompt, range.start, range.end)
      selected = true
    } else if (action.motion) {
      selected = this.moveMotion(action.motion, action.count, true)
    }
    if (!selected) return { handled: false }
    const text = this.selected(prompt)
    if (action.operator === "yank") {
      this.yank(text, linewise)
      prompt.clearSelection?.()
      setCursor(prompt, start)
      return { handled: true }
    }
    prompt.deleteSelection?.()
    prompt.clearSelection?.()
    setCursor(prompt, start)
    if (action.operator === "change") return { handled: true, mode: "insert" }
    return { handled: true }
  }

  execute(action: Action): PromptResult {
    const prompt = this.prompt()
    switch (action.type) {
      case "mode":
        if (action.mode !== "visual" && action.mode !== "visual-line") {
          this.anchor = undefined
          this.visualLine = false
        }
        return { handled: true, mode: action.mode }
      case "clearSelection":
        this.clearSelection()
        return { handled: true }
      case "insert": {
        if (!prompt) return { handled: false, mode: "insert" }
        if (action.at === "after") prompt.moveCursorRight?.()
        if (action.at === "lineStart") {
          if (prompt.gotoLineStart) prompt.gotoLineStart()
          else prompt.gotoLineHome?.()
        }
        if (action.at === "lineEnd") {
          if (prompt.gotoLineTextEnd) prompt.gotoLineTextEnd()
          else prompt.gotoLineEnd?.()
        }
        if (action.at === "openBelow") {
          if (prompt.gotoLineTextEnd) prompt.gotoLineTextEnd()
          else prompt.gotoLineEnd?.()
          prompt.insertText?.("\n")
        }
        if (action.at === "openAbove") {
          if (prompt.gotoLineStart) prompt.gotoLineStart()
          else prompt.gotoLineHome?.()
          prompt.insertText?.("\n")
          prompt.moveCursorUp?.()
        }
        return { handled: true, mode: "insert" }
      }
      case "motion":
        this.moveMotion(action.motion, action.count, action.select)
        return { handled: true }
      case "operator":
        return this.executeOperator(action)
      case "deleteChar": {
        if (!prompt) return { handled: false }
        repeat(action.count, () => prompt.deleteChar?.() ?? false)
        return { handled: true }
      }
      case "replaceChar": {
        if (!prompt) return { handled: false }
        repeat(action.count, () => {
          if (!prompt.deleteChar?.()) return false
          prompt.insertText?.(action.char)
          return true
        })
        return { handled: true }
      }
      case "changeChar": {
        if (!prompt) return { handled: false }
        repeat(action.count, () => prompt.deleteChar?.() ?? false)
        return { handled: true, mode: "insert" }
      }
      case "deleteLine": {
        if (!prompt) return { handled: false }
        const range = linewiseSelection(prompt.plainText, prompt.cursorOffset, action.count, true)
        selectRange(prompt, range.start, range.end)
        prompt.deleteSelection?.()
        prompt.clearSelection?.()
        setCursor(prompt, range.cursor)
        return { handled: true }
      }
      case "changeLine": {
        if (!prompt) return { handled: false }
        const range = linewiseSelection(prompt.plainText, prompt.cursorOffset, action.count, false)
        selectRange(prompt, range.start, range.end)
        prompt.deleteSelection?.()
        prompt.clearSelection?.()
        setCursor(prompt, range.cursor)
        return { handled: true, mode: "insert" }
      }
      case "yankLine": {
        if (!prompt) return { handled: false }
        const start = prompt.cursorOffset
        const range = linewiseSelection(prompt.plainText, start, action.count, true)
        selectRange(prompt, range.start, range.end)
        this.yank(this.selected(prompt), true)
        prompt.clearSelection?.()
        setCursor(prompt, start)
        return { handled: true }
      }
      case "paste": {
        if (!prompt || !this.register) return { handled: false }
        const insert = () => {
          if (this.registerLinewise) {
            if (action.before) {
              prompt.gotoLineStart?.()
              prompt.insertText?.(`${this.register.replace(/\n$/, "")}\n`)
              prompt.moveCursorUp?.()
            } else {
              if (prompt.gotoLineTextEnd) prompt.gotoLineTextEnd()
              else prompt.gotoLineEnd?.()
              prompt.insertText?.(`\n${this.register.replace(/\n$/, "")}`)
            }
            return
          }
          if (!action.before) prompt.moveCursorRight?.()
          prompt.insertText?.(this.register)
        }
        repeat(action.count, () => {
          insert()
          return true
        })
        return { handled: true }
      }
      case "undo":
        prompt?.undo?.()
        return { handled: true }
      case "redo":
        prompt?.redo?.()
        return { handled: true }
      case "visual": {
        if (!prompt) return { handled: false }
        this.anchor = prompt.cursorOffset
        this.visualLine = action.line
        if (action.line) this.selectVisualLines()
        return { handled: true, mode: action.line ? "visual-line" : "visual" }
      }
      case "visualOperator": {
        if (!prompt) return { handled: false }
        const selection = prompt.getSelection?.()
        const text = this.selected(prompt)
        if (action.operator === "yank") {
          this.yank(text, this.visualLine)
          prompt.clearSelection?.()
          setCursor(prompt, selection ? Math.min(selection.start, selection.end) : (this.anchor ?? prompt.cursorOffset))
          return { handled: true, mode: "normal" }
        }
        prompt.deleteSelection?.()
        prompt.clearSelection?.()
        return { handled: true, mode: action.operator === "change" ? "insert" : "normal" }
      }
      case "session":
        return { handled: this.dispatch(action.command) }
      case "help":
        return { handled: true }
      case "noop":
        return { handled: true }
    }
    return { handled: false }
  }
}
