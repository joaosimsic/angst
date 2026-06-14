import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { config } from "./config.js";
import { registerTools } from "./tools/index.js";
import { createApp } from "./transport.js";

async function main() {
  const server = new McpServer({ name: "vm-mcp", version: "1.0.0" });
  registerTools(server, config);
  const app = createApp(server, config);

  app.listen(config.mcpPort, () => {
    console.log(`VM MCP server listening on http://localhost:${config.mcpPort}/mcp`);
  });
}

main().catch(console.error);
