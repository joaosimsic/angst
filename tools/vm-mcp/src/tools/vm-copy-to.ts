import { execSync } from "child_process";
import { z } from "zod";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";

export const name = "vm_copy_to";
export const description = "Copy a file from host to VM";
export const inputSchema = {
  localPath: z.string().describe("Path on host"),
  remotePath: z.string().describe("Path in VM"),
} as const;

export async function handler(
  args: { localPath: string; remotePath: string },
  config: Config,
): Promise<CallToolResult> {
  const scpCmd = `scp -P ${config.sshPort} "${args.localPath}" ${config.sshUser}@${config.sshHost}:${args.remotePath}`;
  execSync(scpCmd, { stdio: "pipe" });
  return {
    content: [{ type: "text", text: `Copied ${args.localPath} to VM:${args.remotePath}` }],
  };
}
