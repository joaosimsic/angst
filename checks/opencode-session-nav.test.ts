import { describe, expect, test } from "bun:test"
import plugin from "../domains/agents/opencode/config/tui-plugins/session-nav.ts"

type HarnessOptions = {
  route?: { name: string; params?: { sessionID?: unknown } }
  status?: { type?: string }
  permissions?: readonly unknown[]
  questions?: readonly unknown[]
  dialogOpen?: boolean
}

function harness(options: HarnessOptions = {}) {
  const state = {
    route: options.route ?? { name: "session", params: { sessionID: "s" } },
    status: options.status ?? { type: "idle" },
    permissions: options.permissions ?? [],
    questions: options.questions ?? [],
    dialogOpen: options.dialogOpen ?? false,
  }
  const dispatches: string[] = []
  const toasts: Array<{ message: string }> = []
  const layers: Array<{ layer: any; disposed: boolean }> = []
  const intercepts: Array<(ctx: any) => void> = []
  const events = new Map<string, Set<(event: any) => void>>()
  const disposers: Array<() => void> = []

  const api = {
    route: {
      get current() {
        return state.route
      },
    },
    mode: { current: () => "base" },
    state: {
      session: {
        status: () => state.status,
        permission: () => state.permissions,
        question: () => state.questions,
      },
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
    renderer: { requestRender() {} },
    keymap: {
      createKeyMatcher: (key: string) => (event: { name: string }) => event.name === key,
      intercept(_name: string, fn: (ctx: any) => void) {
        intercepts.push(fn)
        return () => {
          const index = intercepts.indexOf(fn)
          if (index >= 0) intercepts.splice(index, 1)
        }
      },
      registerLayer(layer: any) {
        const entry = { layer, disposed: false }
        layers.push(entry)
        return () => {
          entry.disposed = true
        }
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
    layers,
    dispatches,
    toasts,
    setRoute(route: { name: string; params?: { sessionID?: unknown } }) {
      state.route = route
    },
    press(name: string) {
      let consumed = 0
      const ctx = {
        event: { name },
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
    run(entry: { layer: any }, key: string) {
      const binding = entry.layer.bindings?.find((item: any) => item.key === key)
      if (!binding) return false
      const command = entry.layer.commands?.find((item: any) => item.name === binding.cmd)
      if (!command) return false
      return command.run()
    },
    dispose() {
      for (const fn of disposers.splice(0)) fn()
    },
  }
}

describe("session navigation", () => {
  test("escape enters navigation and gg/G jump to first and last", async () => {
    const h = harness()
    await plugin.tui(h.api as any)
    expect(h.layers).toHaveLength(0)

    expect(h.press("escape")).toBe(1)
    expect(h.layers).toHaveLength(1)
    expect(h.toasts[0]?.message).toContain("NAV")

    const nav = h.layers[0]!
    expect(nav.disposed).toBe(false)
    expect(h.run(nav, "gg")).toBe(true)
    expect(h.run(nav, "shift+g")).toBe(true)
    expect(h.dispatches).toEqual(["session.first", "session.last"])

    expect(h.run(nav, "return")).toBe(true)
    expect(nav.disposed).toBe(true)
  })

  test("does not enter while busy, blocked, in a dialog, or outside a session", async () => {
    const cases = [
      harness({ status: { type: "busy" } }),
      harness({ permissions: [{}] }),
      harness({ questions: [{}] }),
      harness({ dialogOpen: true }),
      harness({ route: { name: "home" } }),
    ]

    for (const h of cases) {
      await plugin.tui(h.api as any)
      expect(h.press("escape")).toBe(0)
      expect(h.layers).toHaveLength(0)
      expect(h.toasts).toHaveLength(0)
    }
  })

  test("exits when the session becomes busy or the route changes", async () => {
    const h = harness()
    await plugin.tui(h.api as any)

    h.press("escape")
    const first = h.layers[0]!
    h.emit("session.status", { sessionID: "s", status: { type: "busy" } })
    expect(first.disposed).toBe(true)

    h.press("escape")
    const second = h.layers[1]!
    h.setRoute({ name: "home" })
    expect(h.run(second, "gg")).toBe(false)
    expect(second.disposed).toBe(true)
    expect(h.dispatches).toHaveLength(0)
  })

  test("dispose removes the escape interceptor and active navigation layer", async () => {
    const h = harness()
    await plugin.tui(h.api as any)

    h.press("escape")
    const nav = h.layers[0]!
    h.dispose()
    expect(nav.disposed).toBe(true)
    expect(h.press("escape")).toBe(0)
    expect(h.layers).toHaveLength(1)
  })
})
