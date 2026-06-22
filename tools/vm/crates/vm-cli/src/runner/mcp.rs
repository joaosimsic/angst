use crate::commands::McpCommands;
use vm_mcp::{run_server, service};

pub async fn handle(action: McpCommands) -> Result<(), String> {
    match action {
        McpCommands::Start => service::start(),
        McpCommands::Stop => service::stop(),
        McpCommands::Restart => service::restart(),
        McpCommands::Status => {
            println!("MCP Server status: {}", service::status()?);
            Ok(())
        }
        McpCommands::Logs { lines } => service::logs(lines),
        McpCommands::RunServer { port } => {
            run_server(port).await;
            Ok(())
        }
    }
}
