export const config = {
  sshPort: parseInt(process.env.VM_SSH_PORT || "2222"),
  sshUser: process.env.VM_SSH_USER || "joao",
  sshHost: process.env.VM_SSH_HOST || "localhost",
  mcpPort: parseInt(process.env.MCP_PORT || "8765"),
} as const;

export type Config = typeof config;
