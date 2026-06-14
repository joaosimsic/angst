import { z } from "zod";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";
import { sshExec } from "../ssh.js";

export const name = "vm_logs";
export const description = "Get journalctl logs from the VM";
export const inputSchema = {
  unit: z.string().optional().describe("Systemd unit to filter"),
  lines: z.number().optional().describe("Number of lines (default 50)"),
  since: z.string().optional().describe("Time filter (e.g., '1h ago', 'today')"),
} as const;

export async function handler(
  args: { unit?: string; lines?: number; since?: string },
  config: Config,
): Promise<CallToolResult> {
  const lines = args.lines || 50;
  let cmd = `journalctl --no-pager -n ${lines}`;
  if (args.unit) cmd += ` -u ${args.unit}`;
  if (args.since) cmd += ` --since "${args.since}"`;

  const result = await sshExec(cmd, config);
  return {
    content: [{ type: "text", text: result.stdout || result.stderr }],
  };
}
