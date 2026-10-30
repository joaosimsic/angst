import { expect, test } from "bun:test"
import { AttentionPlugin } from "../domains/agents/opencode/config/plugins/attention.ts"

function harness() {
  let rings = 0
  return {
    ring: () => {
      rings += 1
    },
    count: () => rings,
  }
}

test("rings on permission", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ ring: h.ring })
  await plugin.event!({ event: { type: "permission.updated", properties: { sessionID: "s" } } })
  expect(h.count()).toBe(1)
})

test("rings only on busy to idle", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ ring: h.ring })
  await plugin.event!({ event: { type: "session.idle", properties: { sessionID: "s" } } })
  expect(h.count()).toBe(0)
  await plugin.event!({
    event: { type: "session.status", properties: { sessionID: "s", status: { type: "busy" } } },
  })
  await plugin.event!({
    event: { type: "session.status", properties: { sessionID: "s", status: { type: "idle" } } },
  })
  await plugin.event!({ event: { type: "session.idle", properties: { sessionID: "s" } } })
  expect(h.count()).toBe(1)
})

test("ignores unrelated events", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ ring: h.ring })
  await plugin.event!({ event: { type: "message.updated", properties: { sessionID: "s" } } })
  expect(h.count()).toBe(0)
})
