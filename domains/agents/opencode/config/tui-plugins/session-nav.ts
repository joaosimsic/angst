import { createEngine, type Action, type Key, type Mode } from "./vim-core.ts"
import { publishMode } from "./vim-mode.ts"
import { VimPrompt, getPromptTarget } from "./vim-prompt.ts"

type Status = { type?: string }
type Route = { name: string; params?: { sessionID?: unknown } }
type KeyEvent = {
  name: string
  sequence?: string
  ctrl?: boolean
  shift?: boolean
  meta?: boolean
  super?: boolean
  hyper?: boolean
}
type KeyContext = {
  event: KeyEvent
  consume: (options?: { preventDefault?: boolean; stopPropagation?: boolean }) => void
}
type SessionApi = {
  status: (id: string) => Status | undefined
  permission: (id: string) => readonly unknown[]
  question: (id: string) => readonly unknown[]
}
type Api = {
  route: { readonly current: Route }
  mode: { current: () => string }
  state: { session: SessionApi }
  ui: {
    dialog: { readonly open: boolean }
    toast: (input: { title?: string; message: string; duration?: number; variant?: string }) => void
  }
  renderer: {
    requestRender: () => void
    readonly currentFocusedEditor?: unknown
  }
  keymap: {
    intercept: (name: "key", fn: (ctx: KeyContext) => void, options?: { priority?: number }) => () => void
    clearPendingSequence: () => void
    dispatchCommand: (name: string) => { ok: boolean; reason?: string }
  }
  event: {
    on: (
      type: string,
      handler: (event: { properties?: { sessionID?: string; status?: Status } }) => void,
    ) => () => void
  }
  lifecycle: { onDispose: (fn: () => void) => () => void }
}

const PRIORITY = 1000

const HELP = "VIM: i insert · v visual · V line · gg/G top/bottom · ctrl+d/u half page · n/N message"

const isEscape = (key: KeyEvent) =>
  key.name === "escape" || key.name === "esc" || (key.ctrl === true && (key.name === "[" || key.name === "escape"))

const sessionNav = async (api: Api) => {
  const engine = createEngine("insert")
  const runSession = (command: string) => {
    if (!command) return false
    return api.keymap.dispatchCommand(command).ok
  }
  const controller = new VimPrompt(
    () => getPromptTarget(api.renderer.currentFocusedEditor),
    (command) => runSession(command),
    (command) => runSession(command),
  )

  let mode: Mode = "insert"
  let activeKey: string | undefined
  publishMode("insert")

  const routeKey = () => {
    const route = api.route.current
    if (route?.name === "session") {
      const id = route.params?.sessionID
      return typeof id === "string" && id ? `session:${id}` : undefined
    }
    if (route?.name === "home") return "home"
  }

  const sessionID = () => {
    const route = api.route.current
    if (route?.name !== "session") return
    const id = route.params?.sessionID
    return typeof id === "string" && id ? id : undefined
  }

  const canEnter = () => {
    const key = routeKey()
    if (!key) return false
    if (api.mode.current() !== "base") return false
    if (api.ui.dialog.open) return false
    const id = sessionID()
    if (!id) return true
    const status = api.state.session.status(id)
    if (status && status.type !== "idle") return false
    if (api.state.session.permission(id).length > 0) return false
    if (api.state.session.question(id).length > 0) return false
    return true
  }

  const canContinue = () => {
    if (!activeKey) return false
    if (routeKey() !== activeKey) return false
    if (api.mode.current() !== "base") return false
    if (api.ui.dialog.open) return false
    const id = sessionID()
    if (!id) return true
    const status = api.state.session.status(id)
    if (status && status.type !== "idle") return false
    if (api.state.session.permission(id).length > 0) return false
    if (api.state.session.question(id).length > 0) return false
    return true
  }

  const toast = (message: string, duration = 5000) => {
    api.ui.toast({ title: "VIM", message, duration, variant: "info" })
  }

  const setMode = (next: Mode) => {
    mode = next
    engine.setMode(next)
    publishMode(next)
    if (next === "insert" || next === "normal") controller.clearSelection()
    api.keymap.clearPendingSequence()
    api.renderer.requestRender()
  }

  const exit = () => {
    if (mode === "insert") return
    activeKey = undefined
    setMode("insert")
    controller.reset()
    api.renderer.requestRender()
  }

  const apply = (actions: readonly Action[]) => {
    for (const action of actions) {
      switch (action.type) {
        case "mode":
          setMode(action.mode)
          break
        case "insert": {
          const result = controller.execute(action)
          setMode(result.mode ?? "insert")
          break
        }
        case "visual": {
          const result = controller.execute(action)
          setMode(result.mode ?? (action.line ? "visual-line" : "visual"))
          break
        }
        case "visualOperator": {
          const result = controller.execute(action)
          setMode(result.mode ?? "normal")
          break
        }
        case "operator": {
          const result = controller.execute(action)
          if (result.mode) setMode(result.mode)
          break
        }
        case "changeChar":
        case "changeLine": {
          const result = controller.execute(action)
          setMode(result.mode ?? "insert")
          break
        }
        case "help":
          toast(HELP, 8000)
          break
        default:
          controller.execute(action)
          break
      }
    }
  }

  const intercept = (ctx: KeyContext) => {
    const key: Key = ctx.event

    if (mode === "insert") {
      if (!isEscape(key)) return
      if (!canEnter()) return
      ctx.consume()
      activeKey = routeKey()
      setMode("normal")
      return
    }

    if (!canContinue()) {
      exit()
      return
    }

    ctx.consume()
    const result = engine.handle(key)
    apply(result.actions)
  }

  const offIntercept = api.keymap.intercept("key", intercept, { priority: PRIORITY })

  const offEvents = [
    api.event.on("session.status", (event) => {
      if (!activeKey || event?.properties?.sessionID !== sessionID()) return
      if (event?.properties?.status?.type !== "idle") exit()
    }),
    api.event.on("permission.asked", (event) => {
      if (activeKey && event?.properties?.sessionID === sessionID()) exit()
    }),
    api.event.on("question.asked", (event) => {
      if (activeKey && event?.properties?.sessionID === sessionID()) exit()
    }),
  ]

  api.lifecycle.onDispose(() => {
    offIntercept()
    offEvents.forEach((off) => off())
    activeKey = undefined
    controller.reset()
    publishMode("insert")
    api.keymap.clearPendingSequence()
  })
}

const plugin = {
  id: "angst.session-nav",
  tui: sessionNav,
}

export default plugin
