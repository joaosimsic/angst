declare const process: {
  env: Record<string, string | undefined>
  platform: string
  stdout: { isTTY?: boolean; write: (chunk: string) => unknown }
}
declare const Buffer: {
  from: (value: string, encoding: string) => { toString: (encoding: string) => string }
}

function writeOsc52(text: string) {
  const stdout = process.stdout as typeof process.stdout & { isTTY?: boolean }
  if (!stdout?.isTTY) return false
  try {
    const sequence = `\x1b]52;c;${Buffer.from(text, "utf8").toString("base64")}\x07`
    const passthrough = `\x1bPtmux;\x1b${sequence}\x1b\\`
    stdout.write(process.env.TMUX ? sequence + passthrough : process.env.STY ? passthrough : sequence)
    return true
  } catch {
    return false
  }
}

function candidates() {
  const env = process.env
  const list: string[][] = []
  if (env.WAYLAND_DISPLAY) list.push(["wl-copy"])
  if (env.DISPLAY) {
    list.push(["xclip", "-selection", "clipboard", "-in"])
    list.push(["xsel", "--clipboard", "--input"])
  }
  if (process.platform === "darwin") list.push(["pbcopy"])
  if (process.platform === "win32") list.push(["clip"])
  return list
}

async function writeWithCommand(command: string[], text: string) {
  const runtime = (globalThis as any).Bun
  if (!runtime?.spawn) return false
  try {
    const proc = runtime.spawn({
      cmd: command,
      stdin: "pipe",
      stdout: "ignore",
      stderr: "ignore",
    })
    if (!proc?.stdin) return false
    proc.stdin.write(text)
    proc.stdin.end()
    const code = await Promise.race([
      proc.exited as Promise<number>,
      new Promise<number>((resolve) => setTimeout(() => resolve(-1), 1500)),
    ])
    if (code === 0) return true
    try {
      proc.kill?.()
    } catch {}
    return false
  } catch {
    return false
  }
}

export async function copyText(text: string) {
  if (!text) return false
  for (const command of candidates()) {
    if (await writeWithCommand(command, text)) return true
  }
  return writeOsc52(text)
}
