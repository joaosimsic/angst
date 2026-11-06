export type UsageWindowName = "rolling" | "weekly" | "monthly"

export type UsageWindow = {
  status: string
  percent: number
  resetsAt: string
}

export type UsageData = {
  rolling: UsageWindow
  weekly: UsageWindow
  monthly: UsageWindow
  fetchedAt: number
}

const WINDOWS: readonly UsageWindowName[] = ["rolling", "weekly", "monthly"]
const LABEL_WIDTH = Math.max(...WINDOWS.map((name) => name.length))

function record(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null ? (value as Record<string, unknown>) : undefined
}

export function clampPercent(value: unknown): number {
  const number = typeof value === "number" ? value : Number(value)
  if (!Number.isFinite(number)) return 0
  return Math.min(100, Math.max(0, number))
}

function parseWindow(value: unknown): UsageWindow | undefined {
  const window = record(value)
  if (!window) return undefined
  if (typeof window.percent !== "number" && typeof window.percent !== "string") return undefined
  return {
    status: typeof window.status === "string" ? window.status : "unknown",
    percent: clampPercent(window.percent),
    resetsAt: typeof window.resetsAt === "string" ? window.resetsAt : "",
  }
}

export function parseUsage(value: unknown): UsageData | undefined {
  const usage = record(record(value)?.usage)
  if (!usage) return undefined

  const parsed = {} as Record<UsageWindowName, UsageWindow>
  for (const name of WINDOWS) {
    const window = parseWindow(usage[name])
    if (!window) return undefined
    parsed[name] = window
  }

  return {
    rolling: parsed.rolling,
    weekly: parsed.weekly,
    monthly: parsed.monthly,
    fetchedAt: Date.now(),
  }
}

export function formatCountdown(resetsAt: string, now = Date.now()): string {
  const reset = Date.parse(resetsAt)
  if (!Number.isFinite(reset)) return "?"
  const remaining = reset - now
  if (remaining <= 0) return "now"

  const minutes = Math.floor(remaining / 60_000)
  if (minutes < 1) return "<1m"
  if (minutes < 60) return `${minutes}m`

  const hours = Math.floor(minutes / 60)
  if (hours < 24) {
    const rest = minutes % 60
    return rest ? `${hours}h${rest}m` : `${hours}h`
  }

  const days = Math.floor(hours / 24)
  const rest = hours % 24
  return rest ? `${days}d${rest}h` : `${days}d`
}

export function formatRequests(value: number | undefined): string {
  if (value === undefined) return "n/a"
  if (!Number.isFinite(value)) return "∞"
  return Math.round(value).toLocaleString("en-US")
}

export function bar(percent: number, width = 8): string {
  const safe = clampPercent(percent)
  const filled = safe <= 0 ? 0 : Math.max(1, Math.round((safe / 100) * width))
  return "█".repeat(Math.min(width, filled)) + "░".repeat(Math.max(0, width - filled))
}

export type UsageRow = {
  left: string
  percent: string
  bar: string
}

export function usageRow(label: UsageWindowName, window: UsageWindow, now = Date.now(), barWidth = 8): UsageRow {
  return {
    left: `${label.padEnd(LABEL_WIDTH)} | ${formatCountdown(window.resetsAt, now)}`,
    percent: `${Math.round(window.percent)}%`.padStart(4),
    bar: bar(window.percent, barWidth),
  }
}
