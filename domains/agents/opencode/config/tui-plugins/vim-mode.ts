import type { Mode } from "./vim-core.ts"

let current: Mode = "insert"
const listeners = new Set<(mode: Mode) => void>()

export function getMode() {
  return current
}

export function publishMode(mode: Mode) {
  current = mode
  for (const listener of [...listeners]) {
    try {
      listener(mode)
    } catch {}
  }
}

export function subscribeMode(listener: (mode: Mode) => void) {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}
