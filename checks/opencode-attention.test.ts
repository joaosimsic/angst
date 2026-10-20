import { expect, test } from "bun:test"
import { AttentionPlugin } from "../domains/agents/opencode/config/plugins/attention.ts"

function harness() {
  const commands: string[] = []
  const $ = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    commands.push(strings.join("") + values.join(""))
    const promise = Promise.resolve({ stdout: "", exitCode: 0 }) as any
    promise.quiet = () => promise
    promise.nothrow = () => promise
    return promise
  }) as any
  return { $, commands }
}

test("rings on permission", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ $: h.$ })
  await plugin.event!({ event: { type: "permission.updated", properties: { sessionID: "s" } } })
  expect(h.commands).toHaveLength(1)
  expect(h.commands[0]).toContain('printf "\\a"')
  expect(h.commands[0]).toContain("/dev/tty")
})

test("rings only on busy to idle", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ $: h.$ })
  await plugin.event!({ event: { type: "session.idle", properties: { sessionID: "s" } } })
  expect(h.commands).toHaveLength(0)
  await plugin.event!({
    event: { type: "session.status", properties: { sessionID: "s", status: { type: "busy" } } },
  })
  await plugin.event!({
    event: { type: "session.status", properties: { sessionID: "s", status: { type: "idle" } } },
  })
  await plugin.event!({ event: { type: "session.idle", properties: { sessionID: "s" } } })
  expect(h.commands).toHaveLength(1)
})

test("ignores unrelated events", async () => {
  const h = harness()
  const plugin = await AttentionPlugin({ $: h.$ })
  await plugin.event!({ event: { type: "message.updated", properties: { sessionID: "s" } } })
  expect(h.commands).toHaveLength(0)
})
