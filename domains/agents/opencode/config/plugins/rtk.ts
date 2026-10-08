type ShellResult = { stdout: string; exitCode: number }
type ShellPromise = Promise<ShellResult> & {
  quiet: () => ShellPromise
  nothrow: () => ShellPromise
}
type Shell = (strings: TemplateStringsArray, ...values: unknown[]) => ShellPromise

type PluginInput = { $: Shell }

type Hooks = {
  "tool.execute.before"?: (
    input: { tool?: string },
    output: { args?: Record<string, unknown> },
  ) => Promise<void>
}

export const RtkOpenCodePlugin = async ({ $ }: PluginInput): Promise<Hooks> => {
  try {
    await $`which rtk`.quiet()
  } catch {
    console.warn("[rtk] rtk binary not found in PATH — plugin disabled")
    return {}
  }

  return {
    "tool.execute.before": async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const args = output?.args
      if (!args || typeof args !== "object") return

      const command = args.command
      if (typeof command !== "string" || !command) return

      try {
        const result = await $`rtk rewrite ${command}`.quiet().nothrow()
        const rewritten = String(result.stdout).trim()
        if ((result.exitCode === 0 || result.exitCode === 3) && rewritten && rewritten !== command) {
          args.command = rewritten
        }
      } catch {}
    },
  }
}

export default RtkOpenCodePlugin
