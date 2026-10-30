type PluginInput = { ring?: () => void }
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

const writeBell = () => {
  try {
    process.stdout.write("\x07")
  } catch {}
}

export const AttentionPlugin = async ({ ring = writeBell }: PluginInput = {}) => {
  const busy = new Set<string>()
  let lastRing = 0

  const ringBell = async () => {
    const now = Date.now()
    if (now - lastRing < COOLDOWN_MS) return
    lastRing = now
    ring()
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
          await ringBell()
        }
        return
      }

      if (type === "session.idle") {
        if (sessionID && busy.delete(sessionID)) await ringBell()
        return
      }

      if (ATTENTION_EVENTS.has(type)) await ringBell()
    },
  }
}

export default AttentionPlugin
