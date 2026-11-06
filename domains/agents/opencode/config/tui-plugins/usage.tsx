/** @jsxImportSource @opentui/solid */
import type { TuiPlugin, TuiPluginApi, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { createEffect, createSignal, onCleanup, onMount, Show } from "solid-js"
import { fetchUsage, readGoApiKey } from "./usage-api.ts"
import {
  formatRequests,
  usageRow,
  type UsageData,
  type UsageWindow,
  type UsageWindowName,
} from "./usage-format.ts"
import { estRequests5h } from "./usage-models.ts"

const REFRESH_MS = 60_000
const TICK_MS = 30_000
const EVENT_DEBOUNCE_MS = 1_500

type Theme = TuiPluginApi["theme"]["current"]

const truncate = (value: string, width: number) => (value.length > width ? `${value.slice(0, width - 1)}…` : value)

function currentModel(api: TuiPluginApi, sessionID: string): string | undefined {
  const selected = api.state.session.get(sessionID)?.model
  if (selected?.id) return selected.id

  const configured = api.state.config.model
  if (typeof configured === "string") {
    const [provider, ...rest] = configured.split("/")
    if (provider === "opencode-go" && rest.length > 0) return rest.join("/")
    if (!configured.includes("/")) return configured
  }

  const messages = api.state.session.messages(sessionID) as Array<Record<string, unknown>>
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index]
    if (message?.role === "assistant" && typeof message.modelID === "string") return message.modelID
  }

  return undefined
}

function WindowLine(props: { label: UsageWindowName; window: UsageWindow; now: number; theme: Theme }) {
  const row = () => usageRow(props.label, props.window, props.now)
  return (
    <box flexDirection="row" justifyContent="space-between">
      <text fg={props.theme.textMuted}>{row().left}</text>
      <box flexDirection="row" flexShrink={0}>
        <text fg={props.theme.textMuted}>{row().percent} </text>
        <text fg={props.theme.text}>{row().bar}</text>
      </box>
    </box>
  )
}

function UsageWidget(props: { api: TuiPluginApi; sessionID: string }) {
  const apiKey = readGoApiKey()
  const theme = () => props.api.theme.current
  const [data, setData] = createSignal<UsageData>()
  const [error, setError] = createSignal<string>()
  const [model, setModel] = createSignal<string>()
  const [now, setNow] = createSignal(Date.now())

  let controller: AbortController | undefined
  let refreshTimer: ReturnType<typeof setInterval> | undefined
  let tickTimer: ReturnType<typeof setInterval> | undefined
  let debounce: ReturnType<typeof setTimeout> | undefined
  let disposed = false

  const resolveModel = () => {
    setModel(currentModel(props.api, props.sessionID))
  }

  const refresh = async () => {
    if (!apiKey || disposed) return
    controller?.abort()
    const current = new AbortController()
    controller = current
    try {
      const next = await fetchUsage(apiKey, current.signal)
      if (disposed || current.signal.aborted) return
      setData(next)
      setError(undefined)
      void resolveModel()
    } catch (cause) {
      if (disposed || current.signal.aborted) return
      setError(cause instanceof Error ? cause.message : "usage unavailable")
    }
  }

  const schedule = () => {
    clearTimeout(debounce)
    debounce = setTimeout(() => {
      resolveModel()
      void refresh()
    }, EVENT_DEBOUNCE_MS)
  }

  createEffect(() => {
    props.sessionID
    setModel(undefined)
    resolveModel()
    const retries = [250, 1_000, 3_000].map((delay) => setTimeout(resolveModel, delay))
    onCleanup(() => {
      for (const retry of retries) clearTimeout(retry)
    })
  })

  onMount(() => {
    if (!apiKey) return
    resolveModel()
    void refresh()
    refreshTimer = setInterval(() => {
      resolveModel()
      void refresh()
    }, REFRESH_MS)
    tickTimer = setInterval(() => setNow(Date.now()), TICK_MS)
  })

  const offs = apiKey
    ? [props.api.event.on("session.idle", schedule), props.api.event.on("message.updated", schedule)]
    : []

  const offCommand = apiKey
    ? props.api.command?.register(() => [
        {
          title: "Go usage refresh",
          value: "usage.refresh",
          category: "Go",
          onSelect: () => {
            resolveModel()
            void refresh()
          },
        },
      ])
    : undefined

  onCleanup(() => {
    disposed = true
    controller?.abort()
    clearInterval(refreshTimer)
    clearInterval(tickTimer)
    clearTimeout(debounce)
    for (const off of offs) off()
    offCommand?.()
  })

  const estimate = () => estRequests5h(model())

  return (
    <Show when={apiKey}>
      <box gap={0}>
        <text fg={theme().text}>
          <b>Go usage</b>
        </text>
        <Show when={error() && data()}>
          <text fg={theme().textMuted}>stale</text>
        </Show>
        <Show when={data()} fallback={<text fg={theme().textMuted}>{error() ? "unavailable" : "loading..."}</text>}>
          {(usage) => (
            <>
              <WindowLine label="rolling" window={usage().rolling} now={now()} theme={theme()} />
              <WindowLine label="weekly" window={usage().weekly} now={now()} theme={theme()} />
              <WindowLine label="monthly" window={usage().monthly} now={now()} theme={theme()} />
            </>
          )}
        </Show>
        <box marginTop={1}>
          <Show when={model()} fallback={<text fg={theme().textMuted}>model n/a</text>}>
            {(id) => (
              <>
                <text fg={theme().textMuted}>{truncate(id(), 30)}</text>
                <Show when={estimate()} fallback={<text fg={theme().textMuted}>est. req/5h n/a</text>}>
                  {(value) => <text fg={theme().textMuted}>{formatRequests(value())} est. req/5h</text>}
                </Show>
              </>
            )}
          </Show>
        </box>
      </box>
    </Show>
  )
}

const tui: TuiPlugin = async (api) => {
  api.slots.register({
    order: 600,
    slots: {
      sidebar_content(_ctx, props) {
        return <UsageWidget api={api} sessionID={props.session_id} />
      },
    },
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: "angst.go-usage",
  tui,
}

export default plugin
