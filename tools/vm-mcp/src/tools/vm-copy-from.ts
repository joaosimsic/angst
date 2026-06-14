import { execSync } from "child_process";
import { z } from "zod";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";

export const name = "vm_copy_from";
export const description = "Copy a file from VM to host";
export const inputSchema = {
  remotePath: z.string().describe("Path in VM"),
  localPath: z.string().describe("Path on host"),
} as const;

export async function handler(
  args: { remotePath: string; localPath: string },
  config: Config,
): Promise<CallToolResult> {
  const scpCmd = `scp -P ${config.sshPort} ${config.sshUser}@${config.sshHost}:${args.remotePath} "${args.localPath}"`;
  execSync(scpCmd, { stdio: "pipe" });
  return {
    content: [{ type: "text", text: `Copied VM:${args.remotePath} to ${args.localPath}` }],
  };
}
