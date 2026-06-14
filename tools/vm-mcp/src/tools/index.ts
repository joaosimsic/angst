import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { Config } from "../config.js";
import * as vmExec from "./vm-exec.js";
import * as vmStatus from "./vm-status.js";
import * as vmRestart from "./vm-restart.js";
import * as vmLogs from "./vm-logs.js";
import * as vmCopyTo from "./vm-copy-to.js";
import * as vmCopyFrom from "./vm-copy-from.js";

export function registerTools(server: McpServer, config: Config) {
  server.registerTool(vmExec.name, {
    description: vmExec.description,
    inputSchema: vmExec.inputSchema,
  }, (args) => vmExec.handler(args, config));

  server.registerTool(vmStatus.name, {
    description: vmStatus.description,
  }, () => vmStatus.handler(undefined, config));

  server.registerTool(vmRestart.name, {
    description: vmRestart.description,
  }, () => vmRestart.handler(undefined, config));

  server.registerTool(vmLogs.name, {
    description: vmLogs.description,
    inputSchema: vmLogs.inputSchema,
  }, (args) => vmLogs.handler(args, config));

  server.registerTool(vmCopyTo.name, {
    description: vmCopyTo.description,
    inputSchema: vmCopyTo.inputSchema,
  }, (args) => vmCopyTo.handler(args, config));

  server.registerTool(vmCopyFrom.name, {
    description: vmCopyFrom.description,
    inputSchema: vmCopyFrom.inputSchema,
  }, (args) => vmCopyFrom.handler(args, config));
}
