import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";
import { isSshReachable } from "../ssh.js";

export const name = "vm_status";
export const description = "Check if the VM is running (SSH reachable)";
export const inputSchema = undefined;

export async function handler(
  _args: undefined,
  config: Config,
): Promise<CallToolResult> {
  const running = await isSshReachable(config);
  return {
    content: [{ type: "text", text: running ? "VM is running" : "VM is not running" }],
  };
}
