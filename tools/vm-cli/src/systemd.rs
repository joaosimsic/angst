use crate::ssh::{run, run_capture};

pub fn service_start(name: &str) -> Result<(), String> {
    run("systemctl", &["--user", "start", name])
}

pub fn service_stop(name: &str) -> Result<(), String> {
    run("systemctl", &["--user", "stop", name])
}

pub fn service_restart(name: &str) -> Result<(), String> {
    run("systemctl", &["--user", "restart", name])
}

pub fn service_is_active(name: &str) -> Result<bool, String> {
    let output = run_capture("systemctl", &["--user", "is-active", name])?;
    Ok(output.trim() == "active")
}

pub fn service_logs(unit: &str, lines: u32) -> Result<(), String> {
    let lines = lines.to_string();
    run(
        "journalctl",
        &["--user", "-u", unit, "-n", &lines, "--no-pager", "-f"],
    )
}
