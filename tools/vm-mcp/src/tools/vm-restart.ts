import { execSync } from "child_process";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";

export const name = "vm_restart";
export const description = "Restart the VM via systemctl --user restart vm";
export const inputSchema = undefined;

export async function handler(
  _args: undefined,
  _config: Config,
): Promise<CallToolResult> {
  execSync("systemctl --user restart vm", { stdio: "pipe" });
  return {
    content: [{ type: "text", text: "VM restart initiated" }],
  };
}
