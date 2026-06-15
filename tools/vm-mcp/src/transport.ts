import { randomUUID } from "crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import type { Config } from "./config.js";
import { registerTools } from "./tools/index.js";
import { isSshReachable } from "./ssh.js";

function createServer(config: Config): McpServer {
  const server = new McpServer({ name: "vm-mcp", version: "1.0.0" });
  registerTools(server, config);
  return server;
}

export function createApp(config: Config) {
  const app = createMcpExpressApp();
  const transports = new Map<string, StreamableHTTPServerTransport>();

  app.post("/mcp", async (req, res) => {
    const sessionId = (req.headers["mcp-session-id"] as string) || randomUUID();
    let transport = transports.get(sessionId);

    if (!transport) {
      transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => sessionId,
      });
      transports.set(sessionId, transport);
      const server = createServer(config);
      await server.connect(transport);
    }

    await transport.handleRequest(req, res, req.body);
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

  app.delete("/mcp", async (req, res) => {
    const sessionId = req.headers["mcp-session-id"] as string;
    const transport = transports.get(sessionId);

    if (transport) {
      await transport.close();
      transports.delete(sessionId);
    }

    res.status(204).send();
  });

  app.get("/health", async (_req, res) => {
    const vmReachable = await isSshReachable(config);
    res.json({ status: "ok", vmReachable });
  });

  return app;
}
