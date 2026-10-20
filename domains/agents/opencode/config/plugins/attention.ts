type ShellResult = { stdout: string; exitCode: number }
type ShellPromise = Promise<ShellResult> & {
  quiet: () => ShellPromise
  nothrow: () => ShellPromise
}
type Shell = (strings: TemplateStringsArray, ...values: unknown[]) => ShellPromise

type PluginInput = { $: Shell }
type EventInput = {
  event?: {
    type?: string
    properties?: {
      sessionID?: string
      status?: { type?: string }
    }
  }
}

const ATTENTION_EVENTS = new Set([
  "permission.updated",
  "permission.asked",
  "question.asked",
  "session.error",
])

const COOLDOWN_MS = 1000

export const AttentionPlugin = async ({ $ }: PluginInput) => {
  const busy = new Set<string>()
  let lastRing = 0

  const ring = async () => {
    const now = Date.now()
    if (now - lastRing < COOLDOWN_MS) return
    lastRing = now
    await $`sh -c 'printf "\\a" > /dev/tty'`.quiet().nothrow()
  }

  return {
    event: async ({ event }: EventInput) => {
      const type = String(event?.type ?? "")
      const sessionID = String(event?.properties?.sessionID ?? "")

      if (type === "session.status") {
        const status = String(event?.properties?.status?.type ?? "")
        if (!sessionID) return
        if (status === "busy" || status === "retry") {
          busy.add(sessionID)
        } else if (status === "idle" && busy.delete(sessionID)) {
          await ring()
        }
        return
      }

      if (type === "session.idle") {
        if (sessionID && busy.delete(sessionID)) await ring()
        return
      }

      if (ATTENTION_EVENTS.has(type)) await ring()
    },
  }
}

export default AttentionPlugin
