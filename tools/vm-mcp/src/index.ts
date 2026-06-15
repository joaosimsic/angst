import { config } from "./config.js";
import { createApp } from "./transport.js";

async function main() {
  const app = createApp(config);

  app.listen(config.mcpPort, () => {
    console.log(`VM MCP server listening on http://localhost:${config.mcpPort}/mcp`);
  });
}

main().catch(console.error);
