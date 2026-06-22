use crate::process::{io::StateManager, state::VmState, sys::Sys};
use std::{
    ffi::OsStr,
    fs::{self, File},
    io::Write,
    path::Path,
};

pub struct VmProcessController;

impl VmProcessController {
    pub fn start(service: &str, headless: bool) -> Result<(), String> {
        let (log_file_path, log_file, err_file) = Self::prepare_service_start(service)?;

        println!("Spawning background VM process via nix run target...");

        let pid = Sys::spawn_background_runner(log_file, err_file, headless)?;

        Self::write_started_state(service, pid, log_file_path)
    }

    pub fn start_command<I, S>(service: &str, program: &str, args: I) -> Result<(), String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        let (log_file_path, mut log_file, err_file) = Self::prepare_service_start(service)?;

        println!(
            "Spawning background service '{}' via {}...",
            service, program
        );
        let _ = writeln!(
            log_file,
            "Starting service '{}' via {}...",
            service, program
        );

        let pid = Sys::spawn_background_command(program, args, log_file, err_file)?;
        Self::append_log(
            &log_file_path,
            &format!("Service '{}' spawned with PID {}.", service, pid),
        );

        Self::write_started_state(service, pid, log_file_path)
    }

    fn prepare_service_start(service: &str) -> Result<(std::path::PathBuf, File, File), String> {
        let log_dir = StateManager::state_dir().join("logs");

        fs::create_dir_all(&log_dir)
            .map_err(|e| format!("Failed to create log directory: {}", e))?;

        let log_file_path = log_dir.join(format!("{}.log", service));

        if let Some(state) = StateManager::read(service)
            && Sys::is_pid_alive(state.pid)
        {
            Self::append_log(
                &log_file_path,
                &format!(
                    "Service '{}' is already running (PID: {}).",
                    service, state.pid
                ),
            );
            return Err(format!(
                "Service '{}' is already running (PID: {}).",
                service, state.pid
            ));
        }

        File::create(&log_file_path).map_err(|e| format!("Failed to create log file: {}", e))?;

        let log_file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_file_path)
            .map_err(|e| format!("Failed to open log file: {}", e))?;

        let err_file = log_file.try_clone().map_err(|e| e.to_string())?;

        Ok((log_file_path, log_file, err_file))
    }

    fn append_log(path: &Path, message: &str) {
        if let Ok(mut file) = fs::OpenOptions::new().create(true).append(true).open(path) {
            let _ = writeln!(file, "{}", message);
        }
    }

    fn write_started_state(
        service: &str,
        pid: u32,
        log_file_path: std::path::PathBuf,
    ) -> Result<(), String> {
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
                    println!("Sending SIGTERM to service process (PID: {})...", state.pid);
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

    pub fn restart(service: &str, headless: bool) -> Result<(), String> {
        let _ = Self::stop(service);
        Self::start(service, headless)
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
