pub mod protocol;
pub mod server;
pub mod tools;

pub use server::run_server;

pub mod service {
    use vm_core::VmProcessController;

    const SERVICE_NAME: &str = "vm-mcp";
    const DEFAULT_PORT: u16 = 8765;

    pub fn start() -> Result<(), String> {
        let exe = std::env::current_exe()
            .map_err(|e| format!("Failed to resolve current executable: {}", e))?;
        let exe = exe.to_string_lossy().into_owned();
        let port = DEFAULT_PORT.to_string();

        VmProcessController::start_command(
            SERVICE_NAME,
            &exe,
            ["mcp", "run-server", "--port", port.as_str()],
        )
    }

    pub fn stop() -> Result<(), String> {
        VmProcessController::stop(SERVICE_NAME)
    }

    pub fn restart() -> Result<(), String> {
        let _ = stop();
        start()
    }

    pub fn status() -> Result<String, String> {
        VmProcessController::is_active(SERVICE_NAME)
    }

    pub fn logs(lines: u32) -> Result<(), String> {
        VmProcessController::stream_logs(SERVICE_NAME, lines)
    }
}
