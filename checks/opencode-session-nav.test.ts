import { CopyVisual } from "../domains/agents/opencode/config/tui-plugins/vim-copy.ts"
import { describe, expect, test } from "bun:test"
import plugin from "../domains/agents/opencode/config/tui-plugins/session-nav.ts"
import { ChatVisual } from "../domains/agents/opencode/config/tui-plugins/vim-chat.ts"
import { getMode } from "../domains/agents/opencode/config/tui-plugins/vim-mode.ts"

type KeyInput = {
  name: string
  sequence?: string
  ctrl?: boolean
  shift?: boolean
  meta?: boolean
  super?: boolean
}

type Prompt = ReturnType<typeof fakePrompt>

function fakePrompt(initial = "", cursor = 0) {
  let text = initial
  let offset = Math.max(0, Math.min(cursor, initial.length))
  let selection: { start: number; end: number } | null = null
  const history: Array<{ text: string; offset: number }> = []
  const redo: Array<{ text: string; offset: number }> = []

  const save = () => {
    history.push({ text, offset })
    redo.length = 0
  }
  const clamp = (value: number) => Math.max(0, Math.min(value, text.length))

  return {
    get plainText() {
      return text
    },
    get cursorOffset() {
      return offset
    },
    set cursorOffset(value: number) {
      offset = clamp(value)
    },
    getSelectedText() {
      if (!selection) return ""
      return text.slice(Math.min(selection.start, selection.end), Math.max(selection.start, selection.end))
    },
    getSelection() {
      return selection
    },
    setSelection(start: number, end: number) {
      selection = { start: clamp(start), end: clamp(end) }
    },
    clearSelection() {
      selection = null
    },
    deleteSelection() {
      if (!selection) return false
      save()
      const start = Math.min(selection.start, selection.end)
      const end = Math.max(selection.start, selection.end)
      text = text.slice(0, start) + text.slice(end)
      offset = clamp(start)
      selection = null
      return true
    },
    insertText(value: string) {
      if (selection) this.deleteSelection()
      save()
      text = text.slice(0, offset) + value + text.slice(offset)
      offset = clamp(offset + value.length)
      return true
    },
    deleteChar() {
      if (selection) return this.deleteSelection()
      if (offset >= text.length) return false
      save()
      text = text.slice(0, offset) + text.slice(offset + 1)
      return true
    },
    moveCursorLeft() {
      selection = null
      offset = clamp(offset - 1)
      return true
    },
    moveCursorRight() {
      selection = null
      offset = clamp(offset + 1)
      return true
    },
    moveCursorUp() {
      const lineStart = text.lastIndexOf("\n", Math.max(0, offset - 1)) + 1
      if (lineStart === 0) return false
      const previousStart = text.lastIndexOf("\n", Math.max(0, lineStart - 2)) + 1
      offset = Math.max(previousStart, Math.min(lineStart - 1, previousStart + (offset - lineStart)))
      selection = null
      return true
    },
    moveCursorDown() {
      const lineStart = text.lastIndexOf("\n", Math.max(0, offset - 1)) + 1
      const next = text.indexOf("\n", offset)
      if (next === -1) return false
      const nextStart = next + 1
      const nextEnd = text.indexOf("\n", nextStart)
      offset = Math.min(nextEnd === -1 ? text.length : nextEnd, nextStart + (offset - lineStart))
      selection = null
      return true
    },
    moveWordForward() {
      selection = null
      const match = text.slice(offset).match(/^\W*\w+\W*/)
      if (!match) {
        offset = text.length
        return true
      }
      offset = clamp(offset + match[0].length)
      return true
    },
    moveWordBackward() {
      selection = null
      const match = text.slice(0, offset).match(/\w+\W*$/)
      if (!match) {
        offset = 0
        return true
      }
      offset = clamp(offset - match[0].length)
      return true
    },
    gotoLineStart() {
      selection = null
      offset = text.lastIndexOf("\n", Math.max(0, offset - 1)) + 1
      return true
    },
    gotoLineEnd() {
      selection = null
      const next = text.indexOf("\n", offset)
      offset = next === -1 ? text.length : next
      return true
    },
    gotoBufferHome() {
      selection = null
      offset = 0
      return true
    },
    gotoBufferEnd() {
      selection = null
      offset = text.length
      return true
    },
    undo() {
      const previous = history.pop()
      if (!previous) return false
      redo.push({ text, offset })
      text = previous.text
      offset = previous.offset
      selection = null
      return true
    },
    redo() {
      const next = redo.pop()
      if (!next) return false
      history.push({ text, offset })
      text = next.text
      offset = next.offset
      selection = null
      return true
    },
  }
}

function fakeChatRenderer() {
  const calls = { start: 0, update: 0, clear: 0 }
  const scrollCalls: number[] = []
  const boxes = new Map<string, any>()
  const children: any[] = []
  let container: any = null
  let selectionText = ""
  const content: any = {
    x: 0,
    y: 0,
    width: 30,
    height: 20,
    getChildren: () => children,
    findDescendantById: (id: string) => boxes.get(id),
  }
  const scrollbox: any = {
    x: 0,
    y: 0,
    width: 30,
    height: 20,
    content,
    scrollBy(delta: number) {
      scrollCalls.push(delta)
      content.y -= delta
      for (const child of children) child.y -= delta
    },
    getChildren: () => [content],
  }
  const root: any = {
    getChildren: () => [scrollbox],
    findDescendantById: (id: string) => boxes.get(id),
  }
  const renderer: any = {
    root,
    requestRender() {},
    getSelection: () => ({ getSelectedText: () => selectionText }),
    getSelectionContainer: () => container,
    startSelection(anchor: any) {
      calls.start += 1
      container = anchor.parent ?? content
    },
    updateSelection(renderable: any) {
      calls.update += 1
      if (!renderable) container = content
    },
    clearSelection() {
      calls.clear += 1
      container = null
    },
  }
  return {
    renderer,
    calls,
    scrollCalls,
    setSelectionText(text: string) {
      selectionText = text
    },
    addUser(id: string, y: number, height = 2) {
      const box: any = {
        id,
        x: 0,
        y,
        width: 30,
        height,
        selectable: true,
        parent: content,
        getChildren: () => [],
      }
      boxes.set(id, box)
      children.push(box)
      return box
    },
  }
}

type HarnessOptions = {
  route?: { name: string; params?: { sessionID?: unknown } }
  status?: { type?: string }
  permissions?: readonly unknown[]
  questions?: readonly unknown[]
  dialogOpen?: boolean
  mode?: string
  prompt?: Prompt | null
  messages?: readonly { id: string; role: string }[]
  parts?: Record<string, readonly { type?: string; text?: string; synthetic?: boolean }[]>
  renderer?: any
}

function harness(options: HarnessOptions = {}) {
  const state = {
    route: options.route ?? { name: "session", params: { sessionID: "s" } },
    status: options.status ?? { type: "idle" },
    permissions: options.permissions ?? [],
    questions: options.questions ?? [],
    dialogOpen: options.dialogOpen ?? false,
    mode: options.mode ?? "base",
    prompt: options.prompt === undefined ? null : options.prompt,
    messages: options.messages ?? [],
    parts: options.parts ?? {},
  }
  const dispatches: string[] = []
  const toasts: Array<{ message: string }> = []
  const intercepts: Array<(ctx: any) => void> = []
  const events = new Map<string, Set<(event: any) => void>>()
  const disposers: Array<() => void> = []

  const api = {
    route: {
      get current() {
        return state.route
      },
    },
    mode: { current: () => state.mode },
    state: {
      session: {
        status: () => state.status,
        permission: () => state.permissions,
        question: () => state.questions,
        messages: () => state.messages,
      },
      part: (id: string) => state.parts[id] ?? [],
    },
    ui: {
      dialog: {
        get open() {
          return state.dialogOpen
        },
      },
      toast(input: { message: string }) {
        toasts.push(input)
      },
    },
    renderer: {
      requestRender() {},
      get currentFocusedEditor() {
        return state.prompt ?? undefined
      },
      ...options.renderer,
    },
    keymap: {
      createKeyMatcher: (key: string) => (event: { name: string }) => event.name === key,
      intercept(_name: string, fn: (ctx: any) => void) {
        intercepts.push(fn)
        return () => {
          const index = intercepts.indexOf(fn)
          if (index >= 0) intercepts.splice(index, 1)
        }
      },
      registerLayer() {
        return () => {}
      },
      clearPendingSequence() {},
      dispatchCommand(name: string) {
        dispatches.push(name)
        return { ok: true }
      },
    },
    event: {
      on(type: string, handler: (event: any) => void) {
        const handlers = events.get(type) ?? new Set()
        handlers.add(handler)
        events.set(type, handlers)
        return () => {
          handlers.delete(handler)
        }
      },
    },
    lifecycle: {
      onDispose(fn: () => void) {
        disposers.push(fn)
        return () => {}
      },
    },
  }

  return {
    api,
    dispatches,
    toasts,
    state,
    setRoute(route: { name: string; params?: { sessionID?: unknown } }) {
      state.route = route
    },
    setStatus(status: { type?: string }) {
      state.status = status
    },
    setDialog(open: boolean) {
      state.dialogOpen = open
    },
    setMode(mode: string) {
      state.mode = mode
    },
    setPrompt(prompt: Prompt | null) {
      state.prompt = prompt
    },
    press(input: KeyInput | string) {
      const key = typeof input === "string" ? { name: input } : input
      let consumed = 0
      const ctx = {
        event: key,
        consume() {
          consumed += 1
        },
      }
      for (const intercept of [...intercepts]) intercept(ctx)
      return consumed
    },
    emit(type: string, properties: Record<string, unknown>) {
      for (const handler of [...(events.get(type) ?? [])]) handler({ properties })
    },
    dispose() {
      for (const fn of disposers.splice(0)) fn()
    },
  }
}

async function loaded(options: HarnessOptions = {}) {
  const h = harness(options)
  await plugin.tui(h.api as any)
  return h
}

describe("vim modes", () => {
  test("escape enters normal and session motions dispatch", async () => {
    const h = await loaded()

    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")

    h.press("j")
    h.press("k")
    expect(h.dispatches).toEqual(["session.line.down", "session.line.up"])

    h.press({ name: "g" })
    h.press({ name: "g" })
    h.press({ name: "g", shift: true })
    h.press({ name: "d", ctrl: true })
    h.press({ name: "u", ctrl: true })
    h.press("n")
    expect(h.dispatches.slice(2)).toEqual([
      "session.first",
      "session.last",
      "session.half.page.down",
      "session.half.page.up",
      "session.message.next",
    ])

    expect(h.press("i")).toBe(1)
    expect(getMode()).toBe("insert")
    expect(h.press("j")).toBe(0)
    expect(h.dispatches).toHaveLength(7)
  })

  test("does not enter while blocked, in a dialog, or outside a prompt route", async () => {
    const cases = [
      harness({ permissions: [{}] }),
      harness({ questions: [{}] }),
      harness({ dialogOpen: true }),
      harness({ mode: "modal" }),
      harness({ route: { name: "settings" } }),
    ]

    for (const h of cases) {
      await plugin.tui(h.api as any)
      expect(h.press("escape")).toBe(0)
      expect(h.toasts).toHaveLength(0)
    }
  })

  test("enters and stays normal while the session is busy", async () => {
    const h = await loaded({ status: { type: "busy" } })
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")
    h.emit("session.status", { sessionID: "s", status: { type: "busy" } })
    expect(h.press("j")).toBe(1)
    expect(h.dispatches).toEqual(["session.line.down"])
  })

  test("normal escape interrupts a busy session", async () => {
    const h = await loaded({ status: { type: "busy" } })
    h.press("escape")
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")
    expect(h.dispatches).toEqual(["session.interrupt"])
  })

  test("normal escape interrupts a retrying session", async () => {
    const h = await loaded({ status: { type: "retry" } })
    h.press("escape")
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")
    expect(h.dispatches).toEqual(["session.interrupt"])
  })

  test("normal escape returns to insert when idle", async () => {
    const h = await loaded()
    h.press("escape")
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("insert")
    expect(h.dispatches).toHaveLength(0)
  })

  test("normal escape clears pending state without interrupting", async () => {
    const h = await loaded({ status: { type: "busy" } })
    h.press("escape")
    h.press("2")
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")
    expect(h.dispatches).toHaveLength(0)
  })

  test("visual escape does not interrupt a busy session", async () => {
    const h = await loaded({ status: { type: "busy" }, prompt: fakePrompt("abc", 0) })
    h.press("escape")
    h.press("v")
    expect(getMode()).toBe("visual")
    expect(h.press("escape")).toBe(1)
    expect(getMode()).toBe("normal")
    expect(h.dispatches).toHaveLength(0)
  })

  test("Ctrl+C enters normal while busy", async () => {
    const h = await loaded({ status: { type: "busy" } })
    expect(h.press({ name: "c", ctrl: true })).toBe(1)
    expect(getMode()).toBe("normal")
  })

  test("exits when the route changes", async () => {
    const h = await loaded()
    h.press("escape")
    h.setRoute({ name: "home" })
    expect(h.press("j")).toBe(0)
    expect(h.dispatches).toHaveLength(0)
  })

  test("dispose removes the interceptor", async () => {
    const h = await loaded()
    h.press("escape")
    h.dispose()
    expect(h.press("j")).toBe(0)
    expect(h.dispatches).toHaveLength(0)
  })

  test("home prompt can enter normal mode", async () => {
    const h = await loaded({ route: { name: "home" }, prompt: fakePrompt("hello", 5) })
    expect(h.press("escape")).toBe(1)
    h.press("h")
    expect(h.state.prompt?.cursorOffset).toBe(4)
  })

  test("prompt motions, edits, visual mode and operators", async () => {
    const prompt = fakePrompt("alpha beta\ngamma delta", 0)
    const h = await loaded({ prompt })
    h.press("escape")

    h.press("l")
    h.press("l")
    expect(prompt.cursorOffset).toBe(2)
    h.press("0")
    expect(prompt.cursorOffset).toBe(0)
    h.press("$")
    expect(prompt.cursorOffset).toBe(10)

    h.press("0")
    h.press({ name: "d" })
    h.press({ name: "w" })
    expect(prompt.plainText).toBe("beta\ngamma delta")

    h.press({ name: "d" })
    h.press({ name: "d" })
    expect(prompt.plainText).toBe("gamma delta")

    h.press("i")
    expect(h.press("X")).toBe(0)
    prompt.insertText("X")
    expect(prompt.plainText).toBe("Xgamma delta")
    h.press("escape")

    h.press("w")
    h.press("v")
    h.press("e")
    h.press("y")
    h.press("i")
    h.press("esc")
    h.press("escape")
    h.press("p")

    expect(prompt.plainText).toContain("gamma")
  })

  test("text objects and visual line delete", async () => {
    const prompt = fakePrompt('one "two three" four', 6)
    const h = await loaded({ prompt })
    h.press("escape")

    h.press("d")
    h.press("a")
    h.press('"')
    expect(prompt.plainText).toBe("one  four")

    h.press("V")
    h.press("d")
    expect(prompt.plainText).toBe("")
  })

  test("publishes normal, visual, visual-line and insert modes", async () => {
    const h = await loaded({ prompt: fakePrompt("abc", 0) })
    h.press("escape")
    expect(getMode()).toBe("normal")
    h.press("v")
    expect(getMode()).toBe("visual")
    h.press("escape")
    expect(getMode()).toBe("normal")
    h.press("V")
    expect(getMode()).toBe("visual-line")
    h.press("d")
    expect(getMode()).toBe("normal")
    h.press("i")
    expect(getMode()).toBe("insert")
  })

  test("Tab passes through in normal and insert", async () => {
    const insert = await loaded()
    expect(insert.press({ name: "tab" })).toBe(0)

    const normal = await loaded()
    normal.press("escape")
    expect(normal.press({ name: "tab" })).toBe(0)
    expect(normal.press({ name: "tab", shift: true })).toBe(0)
    expect(normal.press({ name: "backtab" })).toBe(0)
    expect(getMode()).toBe("normal")
  })

  test("Ctrl+C enters normal from insert and clears or exits in normal", async () => {
    const text = await loaded({ prompt: fakePrompt("draft", 0) })
    text.press("escape")
    expect(text.press({ name: "c", ctrl: true })).toBe(1)
    expect(text.dispatches).toContain("prompt.clear")
    expect(getMode()).toBe("normal")

    const empty = await loaded()
    empty.press("escape")
    expect(empty.press({ name: "c", ctrl: true })).toBe(0)
    expect(getMode()).toBe("insert")

    const insert = await loaded({ prompt: fakePrompt("draft", 0) })
    insert.press("escape")
    insert.press("i")
    expect(insert.press({ name: "c", ctrl: true })).toBe(1)
    expect(getMode()).toBe("normal")
  })

  test("chat visual selects whole turns", async () => {
    const fake = fakeChatRenderer()
    fake.addUser("u1", 1)
    fake.addUser("u2", 8)
    const messages = [
      { id: "u1", role: "user" },
      { id: "a1", role: "assistant" },
      { id: "u2", role: "user" },
      { id: "a2", role: "assistant" },
    ]
    const parts = {
      u1: [{ type: "text", text: "first" }],
      a1: [{ type: "text", text: "reply one" }],
      u2: [{ type: "text", text: "second" }],
      a2: [{ type: "text", text: "reply two" }],
    }
    const chat = new ChatVisual({
      sessionID: () => "s",
      renderer: fake.renderer,
      messages: () => messages,
      parts: (id) => parts[id as keyof typeof parts] ?? [],
      requestRender() {},
    })

    expect(chat.enter()).toBe(true)
    expect(chat.selectedText()).toBe("second\n\nreply two")
    expect(fake.calls.start).toBeGreaterThan(0)

    expect(chat.handle({ name: "k" })).toBe("stay")
    expect(chat.selectedText()).toBe("first\n\nreply one\n\nsecond\n\nreply two")
    expect(chat.handle({ name: "g" })).toBe("stay")
    expect(chat.handle({ name: "g" })).toBe("stay")
    expect(chat.selectedText()).toBe("first\n\nreply one")
    expect(chat.handle({ name: "G" })).toBe("stay")
    expect(chat.selectedText()).toBe("second\n\nreply two")
    expect(chat.handle({ name: "y" })).toBe("copy")
  })

  test("empty prompt enters contextual chat visual", async () => {
    const fake = fakeChatRenderer()
    fake.addUser("u1", 1)
    fake.addUser("u2", 8)
    const h = await loaded({
      prompt: fakePrompt("", 0),
      renderer: fake.renderer,
      messages: [
        { id: "u1", role: "user" },
        { id: "a1", role: "assistant" },
        { id: "u2", role: "user" },
        { id: "a2", role: "assistant" },
      ],
      parts: {
        u1: [{ type: "text", text: "first" }],
        a1: [{ type: "text", text: "reply one" }],
        u2: [{ type: "text", text: "second" }],
        a2: [{ type: "text", text: "reply two" }],
      },
    })
    h.press("escape")
    h.press("v")
    expect(getMode()).toBe("visual-chat")
    expect(fake.calls.start).toBeGreaterThan(0)
    h.press("escape")
    expect(getMode()).toBe("normal")
    expect(fake.calls.clear).toBeGreaterThan(0)
  })

  test("V uses centered line copy with scrolling selection", async () => {
    const fake = fakeChatRenderer()
    fake.addUser("u1", 8, 5)
    fake.setSelectionText("line one\nline two")
    const h = await loaded({
      prompt: fakePrompt("", 0),
      renderer: fake.renderer,
    })
    h.press("escape")
    h.press("V")
    expect(getMode()).toBe("visual-copy")
    expect(fake.calls.start).toBeGreaterThan(0)
    expect(h.press({ name: "d", ctrl: true })).toBe(1)
    expect(fake.scrollCalls.length).toBeGreaterThan(0)
    h.press({ name: "g" })
    h.press({ name: "g" })
    h.press({ name: "G" })
    h.press("escape")
    expect(getMode()).toBe("normal")
    expect(fake.calls.clear).toBeGreaterThan(0)
  })

  test("CopyVisual copies rendered selection text", () => {
    const fake = fakeChatRenderer()
    fake.addUser("u1", 8, 5)
    fake.setSelectionText("assistant line\ncode line")
    const copy = new CopyVisual({
      renderer: fake.renderer,
      requestRender() {},
    })

    expect(copy.enter()).toBe(true)
    expect(copy.selectedText()).toBe("assistant line\ncode line")
    expect(copy.handle({ name: "j" })).toBe("stay")
    expect(fake.scrollCalls.length).toBeGreaterThan(0)
    expect(copy.handle({ name: "o" })).toBe("stay")
    expect(copy.handle({ name: "G" })).toBe("stay")
    expect(copy.handle({ name: "y" })).toBe("copy")
  })

  test("help and command palette", async () => {
    const h = await loaded()
    h.press("escape")
    h.press("?")
    expect(h.toasts.some((toast) => toast.message.includes("gg/G"))).toBe(true)
    h.press(":")
    expect(h.dispatches.at(-1)).toBe("command.palette.show")
    expect(h.press("j")).toBe(0)
  })

  test("counts, linewise yank and paste", async () => {
    const prompt = fakePrompt("alpha\nbeta\ngamma", 0)
    const h = await loaded({ prompt })
    h.press("escape")

    h.press("2")
    h.press("l")
    expect(prompt.cursorOffset).toBe(2)

    h.press("0")
    h.press("y")
    h.press("y")
    h.press("p")
    expect(prompt.plainText.startsWith("alpha\nalpha\n")).toBe(true)

    h.press("0")
    h.press("2")
    h.press("d")
    h.press("d")
    expect(prompt.plainText.startsWith("alpha\n")).toBe(true)
  })

  test("line-end, change and visual character operations", async () => {
    const prompt = fakePrompt("one two\nthree", 0)
    const h = await loaded({ prompt })
    h.press("escape")

    h.press({ name: "d", shift: true })
    expect(prompt.plainText).toBe("\nthree")

    h.press({ name: "c", shift: true })
    expect(h.press("Z")).toBe(0)
    prompt.insertText("Z")
    h.press("escape")
    expect(prompt.plainText).toContain("Z")

    h.press("v")
    h.press("l")
    h.press("y")
    h.press("p")
    expect(prompt.plainText).toContain("Z")
  })

  test("visual line deletes the whole line", async () => {
    const prompt = fakePrompt("a\nb\nc", 0)
    const h = await loaded({ prompt })
    h.press("escape")
    h.press("V")
    h.press("d")
    expect(prompt.plainText).toBe("b\nc")
  })

  test("replace character", async () => {
    const prompt = fakePrompt("alpha", 0)
    const h = await loaded({ prompt })
    h.press("escape")
    h.press("2")
    h.press("r")
    h.press({ name: "x", sequence: "x" })
    expect(prompt.plainText).toBe("xxpha")
  })

  test("permission and question events exit normal mode", async () => {
    const permission = await loaded()
    permission.press("escape")
    permission.emit("permission.asked", { sessionID: "s" })
    expect(permission.press("j")).toBe(0)

    const question = await loaded()
    question.press("escape")
    question.emit("question.asked", { sessionID: "s" })
    expect(question.press("j")).toBe(0)
  })
})
