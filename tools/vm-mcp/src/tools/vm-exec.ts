import { z } from "zod";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { Config } from "../config.js";
import { sshExec } from "../ssh.js";

export const name = "vm_exec";
export const description = "Execute a command in the NixOS VM via SSH";
export const inputSchema = {
  command: z.string().describe("Command to execute"),
  timeout: z.number().optional().describe("Timeout in ms (default 30000)"),
} as const;

export async function handler(
  args: { command: string; timeout?: number },
  config: Config,
): Promise<CallToolResult> {
  const result = await sshExec(args.command, config, args.timeout);
  return {
    content: [
      {
        type: "text",
        text: `Exit code: ${result.exitCode}\n\nStdout:\n${result.stdout}\n\nStderr:\n${result.stderr}`,
      },
    ],
  };
}
