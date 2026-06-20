use std::process::{Command, Stdio};

pub struct SystemdController;

impl SystemdController {
    fn run_ctl(args: &[&str]) -> Result<String, String> {
        let output = Command::new("systemctl")
            .args(["--user"])
            .args(args)
            .output()
            .map_err(|e| format!("systemctl command error: {}", e))?;

        if output.status.success() {
            Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }

    pub fn start(service: &str) -> Result<(), String> {
        Self::run_ctl(&["start", service]).map(|_| ())
    }

    pub fn stop(service: &str) -> Result<(), String> {
        Self::run_ctl(&["stop", service]).map(|_| ())
    }

    pub fn restart(service: &str) -> Result<(), String> {
        Self::run_ctl(&["restart", service]).map(|_| ())
    }

    pub fn is_active(service: &str) -> Result<bool, String> {
        let status = Self::run_ctl(&["is-active", service]).unwrap_or_default();

        Ok(status.trim() == "active")
    }

    pub fn stream_logs(service: &str, lines: u32) -> Result<(), String> {
        Command::new("journalctl")
            .args([
                "--user",
                "-u",
                service,
                "-n",
                &lines.to_string(),
                "--no-pager",
                "-f",
            ])
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
            .map_err(|e| e.to_string())?;

        Ok(())
    }
}
