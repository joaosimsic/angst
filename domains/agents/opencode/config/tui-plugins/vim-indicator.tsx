/** @jsxImportSource @opentui/solid */
import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { createSignal } from "solid-js"
import type { VimMode } from "./vim-mode.ts"
import { getMode, subscribeMode } from "./vim-mode.ts"

const label = (mode: VimMode) => {
  if (mode === "normal") return "NORMAL"
  if (mode === "visual") return "VISUAL"
  if (mode === "visual-line") return "V-LINE"
  if (mode === "visual-chat") return "V-TURN"
  if (mode === "visual-copy") return "V-COPY"
  return "INSERT"
}

const tui: TuiPlugin = async (api) => {
  const [mode, setMode] = createSignal<VimMode>(getMode())
  const off = subscribeMode((next) => setMode(next))
  api.lifecycle.onDispose(off)

  const view = (value: VimMode) => {
    const theme = api.theme.current
    const color =
      value === "normal"
        ? theme.primary
        : value === "visual" || value === "visual-line" || value === "visual-chat" || value === "visual-copy"
          ? theme.warning
          : theme.info
    return <text fg={color}>{label(value)}</text>
  }

  api.slots.register({
    order: 10,
    slots: {
      session_prompt_right() {
        return view(mode())
      },
      home_prompt_right() {
        return view(mode())
      },
    },
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: "angst.vim-indicator",
  tui,
}

export default plugin
