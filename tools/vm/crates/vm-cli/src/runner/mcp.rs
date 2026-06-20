use crate::commands::McpCommands;
use vm_core::VmProcessController;
use vm_mcp::run_server;

pub async fn handle(action: McpCommands) -> Result<(), String> {
    match action {
        McpCommands::Start => VmProcessController::start("vm-mcp"),
        McpCommands::Stop => VmProcessController::stop("vm-mcp"),
        McpCommands::Restart => VmProcessController::restart("vm-mcp"),
        McpCommands::Status => {
            println!(
                "MCP Server active state: {}",
                VmProcessController::is_active("vm-mcp")?
            );
            Ok(())
        }
        McpCommands::Logs { lines } => VmProcessController::stream_logs("vm-mcp", lines),
        McpCommands::RunServer { port } => {
            run_server(port).await;
            Ok(())
        }
    }
}
