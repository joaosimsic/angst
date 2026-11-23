import { expect, test } from "bun:test"
import { RestartPlugin } from "../domains/agents/opencode/config/plugins/restart.ts"

type Call = { strings: readonly string[]; values: unknown[] }

function harness() {
  const calls: Call[] = []
  const toasts: string[] = []
  const result = Object.assign(Promise.resolve({ stdout: "", exitCode: 0 }), {
    quiet: () => result,
    nothrow: () => result,
  })
  const $ = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    calls.push({ strings: [...strings], values })
    return result
  }) as any
  const client = {
    tui: {
      showToast: async (input: { body: { message: string } }) => {
        toasts.push(input.body.message)
      },
    },
  }
  return { $, client, calls, toasts }
}

function withMuxEnv(fn: () => Promise<void>) {
  const oldDir = process.env.OPENCODE_MUX_DIR
  const oldPort = process.env.OPENCODE_MUX_PORT
  process.env.OPENCODE_MUX_DIR = "/home/joao/projects/TiConnect"
  process.env.OPENCODE_MUX_PORT = "4200"
  return fn().finally(() => {
    if (oldDir === undefined) delete process.env.OPENCODE_MUX_DIR
    else process.env.OPENCODE_MUX_DIR = oldDir
    if (oldPort === undefined) delete process.env.OPENCODE_MUX_PORT
    else process.env.OPENCODE_MUX_PORT = oldPort
  })
}

test("registers the restart command", async () => {
  const h = harness()
  const plugin = await RestartPlugin({ $: h.$, directory: "/tmp/project", client: h.client as any })
  const config: { command?: Record<string, { template: string; description?: string }> } = {}
  await plugin.config!(config)
  expect(config.command?.restart?.template).toBe("Restart requested.")
  expect(config.command?.restart?.description).toContain("Restart")
})

test("ignores unrelated commands", async () => {
  const h = harness()
  const plugin = await RestartPlugin({ $: h.$, directory: "/tmp/project", client: h.client as any })
  await withMuxEnv(async () => {
    await plugin["command.execute.before"]!({ command: "caveman", arguments: "" })
  })
  expect(h.calls.length).toBe(0)
})

test("schedules restart through systemd-run", async () => {
  const h = harness()
  const plugin = await RestartPlugin({ $: h.$, directory: "/tmp/project", client: h.client as any })
  await withMuxEnv(async () => {
    await plugin["command.execute.before"]!({ command: "restart", arguments: "" })
  })
  expect(h.calls.length).toBe(1)
  expect(h.calls[0].strings.join(" ")).toContain("systemd-run")
  expect(h.calls[0].values).toContain("/tmp/project")
  expect(h.calls[0].strings.join(" ")).toContain("opencode-mux")
  expect(h.toasts).toEqual([])
})

test("warns without mux environment", async () => {
  const h = harness()
  const plugin = await RestartPlugin({ $: h.$, directory: "/tmp/project", client: h.client as any })
  const oldDir = process.env.OPENCODE_MUX_DIR
  const oldPort = process.env.OPENCODE_MUX_PORT
  delete process.env.OPENCODE_MUX_DIR
  delete process.env.OPENCODE_MUX_PORT
  try {
    await plugin["command.execute.before"]!({ command: "restart", arguments: "" })
  } finally {
    if (oldDir !== undefined) process.env.OPENCODE_MUX_DIR = oldDir
    if (oldPort !== undefined) process.env.OPENCODE_MUX_PORT = oldPort
  }
  expect(h.calls.length).toBe(0)
  expect(h.toasts.length).toBe(1)
})
