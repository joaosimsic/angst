import { describe, expect, test } from "bun:test"
import {
  bar,
  clampPercent,
  formatCountdown,
  formatRequests,
  parseUsage,
  usageRow,
} from "../domains/agents/opencode/config/tui-plugins/usage-format.ts"
import { GO_EST_REQUESTS_5H, estRequests5h } from "../domains/agents/opencode/config/tui-plugins/usage-models.ts"

const response = {
  usage: {
    rolling: { status: "ok", percent: 38, resetsAt: "2026-11-06T12:00:00.000Z" },
    weekly: { status: "ok", percent: 72, resetsAt: "2026-11-09T00:00:00.000Z" },
    monthly: { status: "rate-limited", percent: 94, resetsAt: "2026-11-24T00:00:00.000Z" },
  },
}

describe("usage parsing", () => {
  test("parses the three Go windows", () => {
    const parsed = parseUsage(response)
    expect(parsed?.rolling.percent).toBe(38)
    expect(parsed?.weekly.percent).toBe(72)
    expect(parsed?.monthly.status).toBe("rate-limited")
  })

  test("clamps percentages", () => {
    expect(clampPercent(-4)).toBe(0)
    expect(clampPercent(140)).toBe(100)
    expect(clampPercent("38")).toBe(38)
    expect(clampPercent("bad")).toBe(0)
  })

  test("rejects malformed responses", () => {
    expect(parseUsage({})).toBeUndefined()
    expect(parseUsage({ usage: { rolling: {} } })).toBeUndefined()
    expect(parseUsage(null)).toBeUndefined()
  })
})

describe("usage formatting", () => {
  test("formats reset countdowns", () => {
    const now = Date.parse("2026-11-06T10:00:00.000Z")
    expect(formatCountdown("2026-11-06T12:14:00.000Z", now)).toBe("2h14m")
    expect(formatCountdown("2026-11-09T14:00:00.000Z", now)).toBe("3d4h")
    expect(formatCountdown("2026-11-06T10:00:30.000Z", now)).toBe("<1m")
    expect(formatCountdown("2026-11-06T09:00:00.000Z", now)).toBe("now")
    expect(formatCountdown("bad", now)).toBe("?")
  })

  test("formats request estimates", () => {
    expect(formatRequests(43330)).toBe("43,330")
    expect(formatRequests(Number.POSITIVE_INFINITY)).toBe("∞")
    expect(formatRequests(undefined)).toBe("n/a")
  })

  test("draws at least one cell for non-zero usage", () => {
    expect(bar(0, 8)).toBe("░░░░░░░░")
    expect(bar(1, 8)).toBe("█░░░░░░░")
    expect(bar(100, 8)).toBe("████████")
  })

  test("aligns labels, percentages and bars", () => {
    const now = Date.parse("2026-11-06T10:00:00.000Z")
    const rows = [
      usageRow("rolling", { status: "ok", percent: 2, resetsAt: "2026-11-06T12:44:00.000Z" }, now),
      usageRow("weekly", { status: "ok", percent: 15, resetsAt: "2026-11-08T20:00:00.000Z" }, now),
      usageRow("monthly", { status: "ok", percent: 63, resetsAt: "2026-11-13T11:00:00.000Z" }, now),
    ]

    expect(rows[0].left).toBe("rolling | 2h44m")
    expect(rows[1].left).toBe("weekly  | 2d10h")
    expect(rows[2].left).toBe("monthly | 7d1h")
    expect(rows.map((row) => row.left.indexOf("|"))).toEqual([8, 8, 8])
    expect(rows.map((row) => row.percent.length)).toEqual([4, 4, 4])
    expect(rows.map((row) => row.bar.length)).toEqual([8, 8, 8])
    expect(rows[0].percent).toBe("  2%")
    expect(rows[1].percent).toBe(" 15%")
    expect(rows[2].percent).toBe(" 63%")
  })
})

describe("Go model estimates", () => {
  test("uses the published DeepSeek V4.1 Flash value", () => {
    expect(estRequests5h("deepseek-v4.1-flash")).toBe(43330)
    expect(GO_EST_REQUESTS_5H["deepseek-v4.1-flash"]).toBe(43330)
  })

  test("normalizes model ids and handles misses", () => {
    expect(estRequests5h(" DeepSeek-V4.1-Flash ")).toBe(43330)
    expect(estRequests5h("opencode-go/deepseek-v4.1-flash")).toBe(43330)
    expect(estRequests5h("deepseek-ai/DeepSeek-V4.1-Flash")).toBe(43330)
    expect(estRequests5h("unknown-model")).toBeUndefined()
    expect(estRequests5h(undefined)).toBeUndefined()
  })

  test("marks unlimited models as infinite", () => {
    expect(estRequests5h("beam-free")).toBe(Number.POSITIVE_INFINITY)
    expect(formatRequests(estRequests5h("beam-free"))).toBe("∞")
  })
})
