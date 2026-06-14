import { execSync } from "child_process";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";

export const name = "vm_restart";
export const description = "Restart the VM (starts if not running)";
export const inputSchema = undefined;

export async function handler(
  _args: undefined,
  config: Config,
): Promise<CallToolResult> {
  const vmCli = config.vmCliPath || "vm";
  execSync(`${vmCli} restart`, { stdio: "pipe" });
  return {
    content: [{ type: "text", text: "VM restart initiated" }],
  };
}
