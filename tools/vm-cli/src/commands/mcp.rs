use crate::systemd;

pub fn start() -> Result<(), String> {
    eprintln!("Starting MCP server...");
    systemd::service_start("vm-mcp")?;
    eprintln!("MCP server started");
    Ok(())
}

pub fn stop() -> Result<(), String> {
    eprintln!("Stopping MCP server...");
    systemd::service_stop("vm-mcp")?;
    eprintln!("MCP server stopped");
    Ok(())
}

pub fn restart() -> Result<(), String> {
    eprintln!("Restarting MCP server...");
    systemd::service_restart("vm-mcp")?;
    eprintln!("MCP server restarted");
    Ok(())
}

pub fn status() -> Result<(), String> {
    if systemd::service_is_active("vm-mcp")? {
        eprintln!("MCP server is running");
        Ok(())
    } else {
        Err("MCP server is not running".into())
    }
}

pub fn logs(lines: u32) -> Result<(), String> {
    systemd::service_logs("vm-mcp", lines)
}
