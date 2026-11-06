import { readFileSync } from "node:fs"
import { request } from "node:https"
import { homedir } from "node:os"
import { join } from "node:path"
import { parseUsage, type UsageData } from "./usage-format.ts"

const USAGE_URL = "https://opencode.ai/zen/go/v1/usage"
const TIMEOUT_MS = 15_000

export function readGoApiKey(): string | undefined {
  const env = process.env.OPENCODE_GO_API_KEY?.trim()
  if (env) return env

  try {
    const raw = readFileSync(join(homedir(), ".local/share/opencode/auth.json"), "utf8")
    const parsed = JSON.parse(raw) as Record<string, unknown>
    for (const name of ["opencode-go", "opencode"]) {
      const entry = parsed[name] as Record<string, unknown> | undefined
      if (entry?.type === "api" && typeof entry.key === "string" && entry.key.trim()) return entry.key.trim()
    }
  } catch {}

  return undefined
}

export function fetchUsage(apiKey: string, signal?: AbortSignal): Promise<UsageData> {
  return new Promise((resolve, reject) => {
    const req = request(
      USAGE_URL,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: "application/json",
        },
        timeout: TIMEOUT_MS,
      },
      (res) => {
        let body = ""
        res.setEncoding("utf8")
        res.on("data", (chunk: string) => {
          body += chunk
        })
        res.on("end", () => {
          signal?.removeEventListener("abort", abort)
          if (res.statusCode !== 200) {
            reject(new Error(`HTTP ${res.statusCode}`))
            return
          }
          try {
            const usage = parseUsage(JSON.parse(body))
            if (!usage) {
              reject(new Error("invalid usage response"))
              return
            }
            resolve(usage)
          } catch {
            reject(new Error("invalid usage response"))
          }
        })
      },
    )

    const abort = () => req.destroy(new Error("usage request aborted"))
    req.on("timeout", () => req.destroy(new Error("usage request timed out")))
    req.on("error", (error) => {
      signal?.removeEventListener("abort", abort)
      reject(error)
    })

    if (signal?.aborted) abort()
    else signal?.addEventListener("abort", abort, { once: true })

    req.end()
  })
}
