use crate::process::{io::StateManager, state::VmState, sys::Sys};
use std::fs::{self, File};

pub struct VmProcessController;

impl VmProcessController {
    pub fn start(service: &str) -> Result<(), String> {
        if let Some(state) = StateManager::read(service) && Sys::is_pid_alive(state.pid) {
            return Err(format!("VM service '{}' is already running (PID: {}).", service, state.pid));
        }

        let log_dir = StateManager::state_dir().join("logs");

        fs::create_dir_all(&log_dir)
            .map_err(|e| format!("Failed to create log directory: {}", e))?;

        let log_file_path = log_dir.join(format!("{}.log", service));

        let log_file = File::create(&log_file_path)
            .map_err(|e| format!("Failed to create log file: {}", e))?;

        let err_file = log_file.try_clone().map_err(|e| e.to_string())?;

        println!("Spawning background VM process via nix run target...");

        let pid = Sys::spawn_background_runner(log_file, err_file)?;

        let state = VmState {
            pid,
            service_name: service.to_string(),
            log_path: log_file_path.to_string_lossy().to_string(),
        };

        StateManager::write(service, &state)?;

        println!("Background process detached successfully with PID: {}", pid);

        Ok(())
    }

    pub fn stop(service: &str) -> Result<(), String> {
        match StateManager::read(service) {
            Some(state) => {
                if Sys::is_pid_alive(state.pid) {
                    println!("Sending SIGTERM to VM process (PID: {})...", state.pid);
                    Sys::terminate_pid(state.pid)?;
                } else {
                    println!(
                        "Process with tracking PID {} was already terminated.",
                        state.pid
                    );
                }

                StateManager::clear(service);

                Ok(())
            }
            None => Err(format!(
                "No state configuration file found for service '{}'.",
                service
            )),
        }
    }

    pub fn restart(service: &str) -> Result<(), String> {
        let _ = Self::stop(service);
        Self::start(service)
    }

    pub fn is_active(service: &str) -> Result<String, String> {
        match StateManager::read(service) {
            Some(state) if Sys::is_pid_alive(state.pid) => Ok("active".to_string()),
            _ => Ok("inactive".to_string()),
        }
    }

    pub fn stream_logs(service: &str, lines: u32) -> Result<(), String> {
        Sys::tail_logs(service, lines)
    }
}
