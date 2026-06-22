use crate::process::io::StateManager;
use std::{
    ffi::OsStr,
    fs::File,
    process::{Command, Stdio},
};

pub struct Sys;

impl Sys {
    pub fn is_pid_alive(pid: u32) -> bool {
        let output = Command::new("kill").args(["-0", &pid.to_string()]).output();

        match output {
            Ok(out) => out.status.success(),
            Err(_) => false,
        }
    }

    pub fn terminate_pid(pid: u32) -> Result<(), String> {
        Command::new("kill")
            .args([&pid.to_string()])
            .status()
            .map_err(|e| format!("Failed to execute kill command: {}", e))?;

        Ok(())
    }

    pub fn spawn_background_runner(
        log_file: File,
        err_file: File,
        headless: bool,
    ) -> Result<u32, String> {
        let mut cmd = Command::new("vm-run");

        cmd.stdout(Stdio::from(log_file))
            .stderr(Stdio::from(err_file));

        if headless {
            cmd.arg("--headless");
            cmd.stdin(Stdio::null());
        }

        let child = cmd
            .spawn()
            .map_err(|e| format!("Failed to spawn VM background process: {}", e))?;

        Ok(child.id())
    }

    pub fn spawn_background_command<I, S>(
        program: &str,
        args: I,
        log_file: File,
        err_file: File,
    ) -> Result<u32, String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        let child = Command::new(program)
            .args(args)
            .stdout(Stdio::from(log_file))
            .stderr(Stdio::from(err_file))
            .stdin(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to spawn background process '{}': {}", program, e))?;

        Ok(child.id())
    }

    pub fn tail_logs(service: &str, lines: u32) -> Result<(), String> {
        let log_file_path = StateManager::state_dir()
            .join("logs")
            .join(format!("{}.log", service));

        if !log_file_path.exists() {
            return Err("No log file found for this VM container instance.".to_string());
        }

        Command::new("tail")
            .args([
                "-n",
                &lines.to_string(),
                "-f",
                &log_file_path.to_string_lossy(),
            ])
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
            .map_err(|e| e.to_string())?;

        Ok(())
    }
}
