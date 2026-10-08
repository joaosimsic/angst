type Level = "lite" | "full" | "ultra" | "off"

type ShellResult = { stdout: string; exitCode: number }
type ShellPromise = Promise<ShellResult> & {
  quiet: () => ShellPromise
  nothrow: () => ShellPromise
}
type Shell = (strings: TemplateStringsArray, ...values: unknown[]) => ShellPromise

type PluginInput = { $: Shell }

type CommandInput = { command: string; arguments: string }
type SystemOutput = { system: string[] }

const LEVELS: Level[] = ["lite", "full", "ultra", "off"]

function isLevel(value: unknown): value is Level {
  return typeof value === "string" && (LEVELS as string[]).includes(value)
}

function rules(level: Level): string {
  const head =
    level === "lite"
      ? "Caveman level: lite. Drop filler and hedging only; keep articles and full sentences. Answer first."
      : level === "ultra"
        ? "Caveman level: ultra. Maximum compression; abbreviate aggressively. Answer first."
        : "Caveman level: full. Drop articles, filler, hedging, pleasantries, and recaps. Fragments fine. Short words. Answer first."
  return [
    head,
    "Never compress code, commands, paths, numbers, identifiers, or error messages; keep them verbatim.",
    "Use plain full sentences (then resume) for security warnings, irreversible actions, multi-step confirmations, and questions back to the user.",
  ].join("\n")
}

export const CavemanPlugin = async ({ $ }: PluginInput) => {
  const homeResult = await $`sh -c 'printf %s "$HOME"'`.quiet().nothrow()
  const home = String(homeResult.stdout).trim() || "/tmp"
  const file = `${home}/.local/state/opencode/caveman.json`

  const readLevel = async (): Promise<Level> => {
    const result = await $`cat ${file}`.quiet().nothrow()
    if (result.exitCode !== 0) return "full"
    try {
      const value = JSON.parse(String(result.stdout)) as { level?: unknown }
      return isLevel(value?.level) ? value.level : "full"
    } catch {
      return "full"
    }
  }

  const writeLevel = async (level: Level): Promise<void> => {
    const script = 'mkdir -p "$(dirname "$2")"; printf "%s" "$1" > "$2"'
    await $`sh -c ${script} _ ${JSON.stringify({ level })} ${file}`.quiet().nothrow()
  }

  return {
    "command.execute.before": async (input: CommandInput) => {
      if (input?.command !== "caveman") return
      const argument = String(input?.arguments ?? "").trim().toLowerCase()
      if (argument === "") {
        await writeLevel((await readLevel()) === "off" ? "full" : "off")
        return
      }
      if (isLevel(argument)) await writeLevel(argument)
    },
    "experimental.chat.system.transform": async (_input: unknown, output: SystemOutput) => {
      const level = await readLevel()
      output.system.push(level === "off" ? "Caveman voice: off. Use normal prose." : rules(level))
    },
  }
}

export default CavemanPlugin
