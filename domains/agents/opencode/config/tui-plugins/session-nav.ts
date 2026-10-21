type Status = { type?: string }
type Route = { name: string; params?: { sessionID?: unknown } }
type KeyEvent = { name: string }
type KeyContext = { event: KeyEvent; consume: () => void }
type SessionApi = {
  status: (id: string) => Status | undefined
  permission: (id: string) => readonly unknown[]
  question: (id: string) => readonly unknown[]
}
type Command = { name: string; run: () => boolean }
type Binding = { key: string; cmd: string; desc: string }
type Layer = {
  priority?: number
  enabled?: () => boolean
  commands?: readonly Command[]
  bindings?: readonly Binding[]
}
type Api = {
  route: { readonly current: Route }
  mode: { current: () => string }
  state: { session: SessionApi }
  ui: {
    dialog: { readonly open: boolean }
    toast: (input: { message: string; duration?: number; variant?: string }) => void
  }
  renderer: { requestRender: () => void }
  keymap: {
    createKeyMatcher: (key: string) => (event: KeyEvent) => boolean
    intercept: (name: "key", fn: (ctx: KeyContext) => void, options?: { priority?: number }) => () => void
    registerLayer: (layer: Layer) => () => void
    clearPendingSequence: () => void
    dispatchCommand: (name: string) => { ok: boolean; reason?: string }
  }
  event: { on: (type: string, handler: (event: { properties?: { sessionID?: string; status?: Status } }) => void) => () => void }
  lifecycle: { onDispose: (fn: () => void) => () => void }
}

const PRIORITY = 1000

const sessionNav = async (api: Api) => {
  let active: string | undefined

  const sessionID = () => {
    const route = api.route.current
    if (route?.name !== "session") return
    const id = route.params?.sessionID
    return typeof id === "string" && id ? id : undefined
  }

  const canEnter = () => {
    const id = sessionID()
    if (!id) return false
    if (api.mode.current() !== "base") return false
    if (api.ui.dialog.open) return false
    const status = api.state.session.status(id)
    if (status && status.type !== "idle") return false
    if (api.state.session.permission(id).length > 0) return false
    if (api.state.session.question(id).length > 0) return false
    return true
  }

  const exit = () => {
    if (!active) return false
    active = undefined
    api.keymap.clearPendingSequence()
    api.renderer.requestRender()
    return true
  }

  const run = (command: string) => {
    if (!active) return false
    if (sessionID() !== active) {
      exit()
      return false
    }
    return api.keymap.dispatchCommand(command).ok
  }

  const enter = () => {
    const id = sessionID()
    if (active || !id || !canEnter()) return false
    active = id
    api.keymap.clearPendingSequence()
    api.ui.toast({ message: "NAV: gg top, G bottom, i exit", duration: 1500, variant: "info" })
    api.renderer.requestRender()
    return true
  }

  api.keymap.registerLayer({
    priority: PRIORITY,
    enabled: () => active !== undefined,
    commands: [
      { name: "angst.session.nav.exit", run: exit },
      { name: "angst.session.nav.first", run: () => run("session.first") },
      { name: "angst.session.nav.last", run: () => run("session.last") },
    ],
    bindings: [
      { key: "gg", cmd: "angst.session.nav.first", desc: "Jump to first message" },
      { key: "shift+g", cmd: "angst.session.nav.last", desc: "Jump to last message" },
      { key: "i", cmd: "angst.session.nav.exit", desc: "Exit navigation mode" },
      { key: "a", cmd: "angst.session.nav.exit", desc: "Exit navigation mode" },
      { key: "return", cmd: "angst.session.nav.exit", desc: "Exit navigation mode" },
    ],
  })

  const escape = api.keymap.createKeyMatcher("escape")
  const offEscape = api.keymap.intercept(
    "key",
    (ctx) => {
      if (!escape(ctx.event)) return
      if (active) {
        if (api.ui.dialog.open) {
          exit()
          return
        }
        ctx.consume()
        exit()
        return
      }
      if (!canEnter()) return
      ctx.consume()
      enter()
    },
    { priority: PRIORITY },
  )

  const offEvents = [
    api.event.on("session.status", (event) => {
      if (!active || event?.properties?.sessionID !== active) return
      if (event?.properties?.status?.type !== "idle") exit()
    }),
    api.event.on("permission.asked", (event) => {
      if (active && event?.properties?.sessionID === active) exit()
    }),
    api.event.on("question.asked", (event) => {
      if (active && event?.properties?.sessionID === active) exit()
    }),
  ]

  api.lifecycle.onDispose(() => {
    offEscape()
    offEvents.forEach((off) => off())
    disposeNav?.()
    disposeNav = undefined
    active = undefined
  })
}

const plugin = {
  id: "angst.session-nav",
  tui: sessionNav,
}

export default plugin
