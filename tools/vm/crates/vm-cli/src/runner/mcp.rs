use crate::commands::McpCommands;
use vm_core::SystemdController;
use vm_mcp::run_server;

pub async fn handle(action: McpCommands) -> Result<(), String> {
    match action {
        McpCommands::Start => SystemdController::start("vm-mcp"),
        McpCommands::Stop => SystemdController::stop("vm-mcp"),
        McpCommands::Restart => SystemdController::restart("vm-mcp"),
        McpCommands::Status => {
            println!(
                "MCP Server active state: {}",
                SystemdController::is_active("vm-mcp")?
            );
            Ok(())
        }
        McpCommands::Logs { lines } => SystemdController::stream_logs("vm-mcp", lines),
        McpCommands::RunServer { port } => {
            run_server(port).await;
            Ok(())
        }
    }
}
