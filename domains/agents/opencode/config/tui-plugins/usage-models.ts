// Go plan estimates from the OpenCode Go model table.
// Keep this in one place so plan changes are easy to audit.
export const GO_EST_REQUESTS_5H: Readonly<Record<string, number>> = {
  "claude-haiku-5-5": 3_850,
  "deepseek-v4.1-flash": 43_330,
  "deepseek-v4-flash": 13_000,
  "deepseek-v4-flash-vision-exp": 6_500,
  "deepseek-v4-pro": 1_050,
  "gemini-4-argon": 440,
  "glm-5.2": 880,
  "glm-5.3": 220,
  "glm-5.3-flash": 6_320,
  "gpt-5.6-luna": 2_050,
  "gpt-6-luna": 4_230,
  "grok-4.6": 169,
  "grok-4.7": 169,
  "hy3": 4_300,
  "hy4": 2_710,
  "hy4-preview": 1_350,
  "kimi-k2.6": 1_150,
  "kimi-k2.7-code": 1_350,
  "kimi-k3": 110,
  "kimi-k3.1-pro": 147,
  "longcat-2.0": 11_400,
  "mimo-v2.5": 30_100,
  "mimo-v2.5-pro": 3_250,
  "mimo-v2.6-flash": 30_100,
  "mimo-v2.6-pro": 3_250,
  "minimax-m2.7": 3_400,
  "minimax-m3": 3_200,
  "minimax-m3.1-flash": 3_880,
  "muse-spark-1.2-contributor": 45_300,
  "muse-spark-1.3-contributor": 45_300,
  "qwen3.7-plus": 4_300,
  "qwen3.8-flash": 5_400,
  "qwen3.8-max": 160,
  "space-bunny": 3_130,
  "beam-free": Number.POSITIVE_INFINITY,
  "crouton-alpha-free": Number.POSITIVE_INFINITY,
  "iceman-contributor-free": Number.POSITIVE_INFINITY,
  "step-5-preview": Number.POSITIVE_INFINITY,
}

export function normalizeModelID(modelID: string): string {
  const parts = modelID.trim().toLowerCase().split("/")
  return parts[parts.length - 1] ?? ""
}

export function estRequests5h(modelID: string | undefined): number | undefined {
  if (!modelID) return undefined
  const normalized = normalizeModelID(modelID)
  if (!normalized) return undefined
  return GO_EST_REQUESTS_5H[normalized]
}
