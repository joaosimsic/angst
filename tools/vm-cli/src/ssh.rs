use std::process::{self, Command};

use crate::config::vm_ssh_identity;

pub fn run(cmd: &str, args: &[&str]) -> Result<(), String> {
    let status = Command::new(cmd)
        .args(args)
        .status()
        .map_err(|e| format!("failed to execute {cmd}: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{cmd} exited with {status}"))
    }
}

pub fn run_capture(cmd: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|e| format!("failed to execute {cmd}: {e}"))?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(format!(
            "{cmd} exited with {}\n{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

pub fn wait_for_ssh(port: &str, user: &str, timeout_secs: u64) -> Result<(), String> {
    let identity = vm_ssh_identity();
    eprintln!("Waiting for SSH...");
    for i in 1..=timeout_secs {
        let status = Command::new("ssh")
            .args([
                "-o",
                "BatchMode=yes",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
                "-o",
                "IdentitiesOnly=yes",
                "-o",
                "ConnectTimeout=1",
                "-i",
                &identity,
                "-p",
                port,
                &format!("{user}@localhost"),
                "true",
            ])
            .stdout(process::Stdio::null())
            .stderr(process::Stdio::null())
            .status();
        if let Ok(s) = status {
            if s.success() {
                eprintln!("VM is ready (SSH on port {port})");
                return Ok(());
            }
        }
        if i % 10 == 0 || i == 1 {
            eprintln!("  {i}s...");
        }
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
    Err(format!(
        "VM started but SSH is not responding after {timeout_secs}s"
    ))
}
