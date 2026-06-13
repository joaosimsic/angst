#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Client, type ConnectConfig } from "ssh2";
import { execSync } from "child_process";
import express from "express";
import { randomUUID } from "crypto";

const config = {
  sshPort: parseInt(process.env.VM_SSH_PORT || "2222"),
  sshUser: process.env.VM_SSH_USER || "joao",
  sshHost: process.env.VM_SSH_HOST || "localhost",
  mcpPort: parseInt(process.env.MCP_PORT || "8765"),
};

function sshExec(command: string, timeout = 30000): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    const result = { stdout: "", stderr: "", exitCode: -1 };

    const timer = setTimeout(() => {
      conn.end();
      reject(new Error("SSH command timeout"));
    }, timeout);

    conn.on("ready", () => {
      conn.exec(command, (err, stream) => {
        if (err) {
          clearTimeout(timer);
          conn.end();
          reject(err);
          return;
        }

        stream.on("close", (code) => {
          clearTimeout(timer);
          conn.end();
          result.exitCode = code || 0;
          resolve(result);
        });

        stream.on("data", (data: Buffer) => { result.stdout += data.toString(); });
        stream.stderr.on("data", (data: Buffer) => { result.stderr += data.toString(); });
      });
    });

    conn.on("error", (err: Error) => {
      clearTimeout(timer);
      reject(err);
    });

    conn.connect({
      host: config.sshHost,
      port: config.sshPort,
      username: config.sshUser,
      agent: process.env.SSH_AUTH_SOCK,
      agentForward: true,
    } as ConnectConfig);
  });
}

async function isSshReachable(): Promise<boolean> {
  try {
    await sshExec("echo ok", 5000);
    return true;
  } catch {
    return false;
  }
}

const server = new Server(
  { name: "vm-mcp", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "vm_exec",
      description: "Execute a command in the NixOS VM via SSH",
      inputSchema: {
        type: "object" as const,
        properties: {
          command: { type: "string", description: "Command to execute" },
          timeout: { type: "number", description: "Timeout in ms (default 30000)" },
        },
        required: ["command"],
      },
    },
    {
      name: "vm_status",
      description: "Check if the VM is running (SSH reachable)",
      inputSchema: { type: "object" as const, properties: {} },
    },
    {
      name: "vm_restart",
      description: "Restart the VM via systemctl --user restart vm",
      inputSchema: { type: "object" as const, properties: {} },
    },
    {
      name: "vm_logs",
      description: "Get journalctl logs from the VM",
      inputSchema: {
        type: "object" as const,
        properties: {
          unit: { type: "string", description: "Systemd unit to filter" },
          lines: { type: "number", description: "Number of lines (default 50)" },
          since: { type: "string", description: "Time filter (e.g., '1h ago', 'today')" },
        },
      },
    },
    {
      name: "vm_copy_to",
      description: "Copy a file from host to VM",
      inputSchema: {
        type: "object" as const,
        properties: {
          localPath: { type: "string", description: "Path on host" },
          remotePath: { type: "string", description: "Path in VM" },
        },
        required: ["localPath", "remotePath"],
      },
    },
    {
      name: "vm_copy_from",
      description: "Copy a file from VM to host",
      inputSchema: {
        type: "object" as const,
        properties: {
          remotePath: { type: "string", description: "Path in VM" },
          localPath: { type: "string", description: "Path on host" },
        },
        required: ["remotePath", "localPath"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "vm_exec": {
        const result = await sshExec(args.command as string, args.timeout as number);
        return {
          content: [{
            type: "text" as const,
            text: `Exit code: ${result.exitCode}\n\nStdout:\n${result.stdout}\n\nStderr:\n${result.stderr}`,
          }],
        };
      }

      case "vm_status": {
        const running = await isSshReachable();
        return { content: [{ type: "text" as const, text: running ? "VM is running" : "VM is not running" }] };
      }

      case "vm_restart": {
        execSync("systemctl --user restart vm", { stdio: "pipe" });
        return { content: [{ type: "text" as const, text: "VM restart initiated" }] };
      }

      case "vm_logs": {
        const lines = args.lines || 50;
        let cmd = `journalctl --no-pager -n ${lines}`;
        if (args.unit) cmd += ` -u ${args.unit}`;
        if (args.since) cmd += ` --since "${args.since}"`;

        const result = await sshExec(cmd);
        return { content: [{ type: "text" as const, text: result.stdout || result.stderr }] };
      }

      case "vm_copy_to": {
        const scpCmd = `scp -P ${config.sshPort} "${args.localPath}" ${config.sshUser}@${config.sshHost}:${args.remotePath}`;
        execSync(scpCmd, { stdio: "pipe" });
        return { content: [{ type: "text" as const, text: `Copied ${args.localPath} to VM:${args.remotePath}` }] };
      }

      case "vm_copy_from": {
        const scpCmd = `scp -P ${config.sshPort} ${config.sshUser}@${config.sshHost}:${args.remotePath} "${args.localPath}"`;
        execSync(scpCmd, { stdio: "pipe" });
        return { content: [{ type: "text" as const, text: `Copied VM:${args.remotePath} to ${args.localPath}` }] };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [{ type: "text" as const, text: `Error: ${(error as Error).message}` }],
      isError: true,
    };
  }
});

const app = express();
app.use(express.json());

const transports = new Map<string, StreamableHTTPServerTransport>();

app.post("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string || randomUUID();

  let transport = transports.get(sessionId);

  if (!transport) {
    transport = new StreamableHTTPServerTransport({ sessionIdGenerator: () => sessionId });
    transports.set(sessionId, transport);
    await server.connect(transport);
  }

  await transport.handleRequest(req, res);
});

app.get("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string;
  const transport = transports.get(sessionId);

  if (!transport) {
    res.status(400).json({ error: "No session found" });
    return;
  }

  await transport.handleRequest(req, res);
});

app.get("/health", async (_req, res) => {
  const vmReachable = await isSshReachable();
  res.json({ status: "ok", vmReachable });
});

app.delete("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string;
  const transport = transports.get(sessionId);

  if (transport) {
    await transport.close();
    transports.delete(sessionId);
  }

  res.status(204).send();
});

async function main() {
  app.listen(config.mcpPort, () => {
    console.log(`VM MCP server listening on http://localhost:${config.mcpPort}/mcp`);
  });
}

main().catch(console.error);
