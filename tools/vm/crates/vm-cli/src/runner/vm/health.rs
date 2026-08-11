use std::fmt;
use std::process::Stdio;
use std::time::Duration;

use vm_core::process::io::StateManager;
use vm_core::SshEngine;

pub fn kill_stale_qemu(disk: &str) {
    let output = std::process::Command::new("sh")
        .args([
            "-c",
            &format!(
                "pids=$(pgrep -f 'qemu-system.*\\b{disk}' 2>/dev/null || true); \
                 [ -n \"$pids\" ] && kill -TERM $pids 2>/dev/null; \
                 echo \"$pids\""
            ),
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output();

    let killed = output
        .ok()
        .and_then(|o| {
            std::str::from_utf8(&o.stdout)
                .ok()
                .map(|s| s.trim().to_string())
        })
        .filter(|s| !s.is_empty());

    if let Some(pids) = killed {
        eprintln!("Killed stale QEMU process(es): {}", pids);
        StateManager::clear("vm");
        StateManager::clear("vm-mcp");
        std::thread::sleep(Duration::from_secs(2));
    }
}

pub fn any_qemu_running() -> bool {
    std::process::Command::new("pgrep")
        .args(["-f", "qemu-system"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn qemu_pid() -> Option<u32> {
    let output = std::process::Command::new("pgrep")
        .args(["-f", "qemu-system.*qcow2"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    let pid_str = std::str::from_utf8(&output.stdout).ok()?.trim().to_string();
    if pid_str.is_empty() {
        None
    } else {
        pid_str.parse().ok()
    }
}

pub fn pid_has_hostfwd(pid: u32) -> bool {
    std::fs::read_to_string(format!("/proc/{pid}/cmdline"))
        .ok()
        .map(|c| c.contains("hostfwd"))
        .unwrap_or(false)
}

pub fn port_listens(port: u16) -> bool {
    let hex = format!("{:04X}", port);
    std::fs::read_to_string("/proc/net/tcp")
        .ok()
        .map(|c| c.lines().any(|l| l.contains(&hex)))
        .unwrap_or(false)
}

pub struct HealthReport {
    pub qemu_running: bool,
    pub qemu_pid: Option<u32>,
    pub hostfwd_present: Option<bool>,
    pub port_listening: Option<bool>,
    pub ssh_reachable: Option<bool>,
}

impl fmt::Display for HealthReport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut check = |ok: bool, label: &str, detail: &str| {
            if ok {
                writeln!(f, "\x1b[32m\u{2713}\x1b[0m {label}  {detail}")
            } else {
                writeln!(f, "\x1b[31m\u{2717}\x1b[0m {label}  {detail}")
            }
        };

        check(
            self.qemu_running,
            "QEMU running",
            &match self.qemu_pid {
                Some(pid) => format!("(PID {pid})"),
                None => "no process found".into(),
            },
        )?;

        if let Some(ok) = self.hostfwd_present {
            check(
                ok,
                "SSH port forwarding",
                if ok {
                    "hostfwd present"
                } else {
                    "hostfwd MISSING"
                },
            )?;
        }

        if let Some(ok) = self.port_listening {
            check(
                ok,
                "Port 2222 listening",
                if ok { "0.0.0.0:2222" } else { "not listening" },
            )?;
        }

        if let Some(ok) = self.ssh_reachable {
            check(
                ok,
                "SSH reachable",
                if ok {
                    "exec true ok"
                } else {
                    "connection refused"
                },
            )?;
        }

        Ok(())
    }
}

pub fn check_health(ssh: &SshEngine) -> HealthReport {
    let qemu_running = any_qemu_running();
    let qemu_pid = if qemu_running { qemu_pid() } else { None };

    let hostfwd_present = qemu_pid.map(|pid| pid_has_hostfwd(pid));

    let port_listening = if qemu_running {
        Some(port_listens(2222))
    } else {
        None
    };

    let ssh_reachable = if port_listening == Some(true) {
        ssh.exec("true").ok().map(|(code, _, _)| code == 0)
    } else {
        None
    };

    HealthReport {
        qemu_running,
        qemu_pid,
        hostfwd_present,
        port_listening,
        ssh_reachable,
    }
}

pub fn health(ssh: &SshEngine) -> Result<(), String> {
    let report = check_health(ssh);
    println!("{}", report);
    if report.ssh_reachable == Some(true) {
        Ok(())
    } else {
        Err("VM is not fully healthy".to_string())
    }
}

pub fn detect_display() -> bool {
    std::env::var_os("DISPLAY").is_some() || std::env::var_os("WAYLAND_DISPLAY").is_some()
}
