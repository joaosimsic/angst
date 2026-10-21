import type { Mode } from "./vim-core.ts"

export type VimMode = Mode | "visual-chat" | "visual-copy"

let current: VimMode = "insert"
const listeners = new Set<(mode: VimMode) => void>()

export function getMode() {
  return current
}

export function publishMode(mode: VimMode) {
  current = mode
  for (const listener of [...listeners]) {
    try {
      listener(mode)
    } catch {}
  }
}

export function subscribeMode(listener: (mode: VimMode) => void) {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}
