use std::env;
use std::fmt;
use std::process::Stdio;
use std::{path::Path, time::Duration};
use tokio::{process::Command, time};
use vm_core::process::io::StateManager;
use vm_core::{SshEngine, VmConfig, VmProcessController};

fn read_env_value(_key: &str) -> Option<String> {
    // Config is now passed via environment variables from the bash wrapper
    // (e.g., ANGST_PASSWORD). No file-based fallback needed.
    None
}

fn target_host() -> String {
    if let Ok(host) = env::var("NIX_TARGET_HOST") {
        if !host.is_empty() {
            return host;
        }
    }

    if let Some(host) = read_env_value("HOST") {
        return host;
    }

    env::var("NIX_DEFAULT_TARGET_HOST")
        .or_else(|_| env::var("ANGST_HOST"))
        .unwrap_or_else(|_| "generic".to_string())
}

fn target_username() -> String {
    if let Ok(user) = env::var("ANGST_USERNAME") {
        if !user.is_empty() {
            return user;
        }
    }

    if let Some(user) = read_env_value("USERNAME") {
        return user;
    }

    VmConfig::load().ssh_user
}

fn kill_stale_qemu(disk: &str) {
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

fn any_qemu_running() -> bool {
    std::process::Command::new("pgrep")
        .args(["-f", "qemu-system"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn qemu_pid() -> Option<u32> {
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

fn pid_has_hostfwd(pid: u32) -> bool {
    std::fs::read_to_string(format!("/proc/{pid}/cmdline"))
        .ok()
        .map(|c| c.contains("hostfwd"))
        .unwrap_or(false)
}

fn port_listens(port: u16) -> bool {
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

fn detect_display() -> bool {
    std::env::var_os("DISPLAY").is_some() || std::env::var_os("WAYLAND_DISPLAY").is_some()
}

pub async fn start(ssh: &SshEngine, headless: bool) -> Result<(), String> {
    let host = target_host();
    let disk = format!("{}.qcow2", host);
    kill_stale_qemu(&disk);

    // Auto-enable headless when no display server is available
    let effective_headless = headless || !detect_display();

    let runner_path = format!("result/bin/run-{}-vm", host);
    let runner_exists = Path::new(&runner_path).exists();

    if !runner_exists {
        println!("VM image not found. Building NixOS VM system image on host...");

        let username = target_username();
        let password = env::var("ANGST_PASSWORD")
            .ok()
            .filter(|p| !p.is_empty())
            .or_else(|| read_env_value("PASSWORD"));

        let mut cmd = Command::new("nix");
        cmd.args([
            "build",
            "--impure",
            "--refresh",
            "--no-write-lock-file",
            &format!(
                ".#nixosConfigurations.{}.config.specialisation.vm.configuration.system.build.vm",
                host
            ),
        ])
        .env("ANGST_USERNAME", &username);

        if let Some(ref p) = password {
            cmd.env("ANGST_PASSWORD", p);
        }

        let build_status = cmd
            .status()
            .await
            .map_err(|e| format!("Failed to run nix build: {}", e))?;

        if !build_status.success() {
            return Err("Nix compilation of the target VM profile failed.".to_string());
        }
    }

    match VmProcessController::start("vm", effective_headless) {
        Ok(()) => {}
        Err(e) if e.contains("already running") => {
            if ssh.exec("true").is_ok() {
                return Err("VM is already running.".to_string());
            }
            eprintln!("Warning: VM process is running but not accepting SSH connections.");
            eprintln!("Run 'vm logs' to check for errors, or 'vm restart' to restart.");
            return Err(
                "VM process is running but SSH is not available. Try 'vm restart'.".to_string(),
            );
        }
        Err(e) => return Err(e),
    }

    println!("VM Started! Validating connection status...");

    for _ in 0..300 {
        if ssh.exec("true").is_ok() {
            println!("VM was initialized and ready via SSH");
            return Ok(());
        }

        time::sleep(Duration::from_secs(1)).await;
    }

    let extra = if any_qemu_running() {
        "\n  QEMU is running but SSH port 2222 is not accepting connections. \
         Check 'vm logs' for boot errors."
    } else {
        "\n  No QEMU process found. Run 'vm logs' for details."
    };

    Err(format!("VM started but SSH connection timed out.{}", extra))
}

pub fn status_message(ssh: &SshEngine) -> Result<String, String> {
    match VmProcessController::is_active("vm") {
        Ok(state) if state == "active" => {
            if ssh.exec("true").is_ok() {
                Ok("VM Status: Running".to_string())
            } else {
                Ok("VM Status: Running (not accepting connections)".to_string())
            }
        }
        Ok(_) => Ok("VM Status: Stopped (No VM is currently running)".to_string()),
        Err(e) => {
            if e.contains("not found") || e.contains("failed to load") {
                return Err("VM service units are not installed. Run './scripts/setup-tools.sh --skip-vm-build' to install them.".to_string());
            }
            Err(format!("Failed to fetch VM status: {}", e))
        }
    }
}

pub fn status(ssh: &SshEngine) -> Result<(), String> {
    println!("{}", status_message(ssh)?);
    Ok(())
}

pub fn ssh(tty: bool, args: Vec<String>) -> Result<(), String> {
    use std::process::Command;

    let config = VmConfig::load();

    let mut cmd = Command::new("ssh");

    cmd.arg("-F")
        .arg("/dev/null")
        .arg("-p")
        .arg(&config.ssh_port)
        .arg("-o")
        .arg("StrictHostKeyChecking=no")
        .arg("-o")
        .arg("UserKnownHostsFile=/dev/null")
        .arg("-o")
        .arg("LogLevel=ERROR")
        .arg("-o")
        .arg("ForwardAgent=yes");

    if tty {
        cmd.arg("-t");
    }

    cmd.arg(format!("{}@127.0.0.1", config.ssh_user));

    if !args.is_empty() {
        cmd.args(args);
    }

    let status = cmd.status().map_err(|e| e.to_string())?;

    if !status.success() {
        println!("Tip: Check 'vm status' and 'vm logs' for VM health.");
        return Err("Interactive SSH session closed with error status".to_string());
    }

    Ok(())
}

pub fn exec(ssh: &SshEngine, command: Vec<String>) -> Result<(), String> {
    let (code, stdout, stderr) = ssh.exec(&command.join(" "))?;

    print!("{}", stdout);
    eprint!("{}", stderr);

    if code == 0 {
        Ok(())
    } else {
        Err(format!("Exited with code: {}", code))
    }
}

#[cfg(test)]
mod tests {
    use super::status_message;
    use std::{
        fs,
        sync::{Mutex, OnceLock},
        time::{SystemTime, UNIX_EPOCH},
    };
    use vm_core::{
        SshEngine, VmProcessController, process::io::StateManager, process::state::VmState,
    };

    static ENV_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

    fn with_temp_state_dir(test: impl FnOnce(&std::path::Path)) {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        let dir = std::env::temp_dir().join(format!(
            "vm-cli-test-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));

        unsafe {
            std::env::set_var("VM_STATE_DIR", &dir);
        }

        test(&dir);

        unsafe {
            std::env::remove_var("VM_STATE_DIR");
        }
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn health_report_formatting_with_all_ok() {
        let report = super::HealthReport {
            qemu_running: true,
            qemu_pid: Some(12345),
            hostfwd_present: Some(true),
            port_listening: Some(true),
            ssh_reachable: Some(true),
        };
        let out = report.to_string();
        assert!(
            out.contains("QEMU running"),
            "should show qemu check:\n{out}"
        );
        assert!(out.contains("12345"), "should show pid:\n{out}");
        assert!(
            out.contains("hostfwd present"),
            "should show hostfwd:\n{out}"
        );
        assert!(out.contains("0.0.0.0:2222"), "should show port:\n{out}");
        assert!(out.contains("exec true ok"), "should show ssh:\n{out}");
    }

    #[test]
    fn health_report_formatting_with_failures() {
        let report = super::HealthReport {
            qemu_running: false,
            qemu_pid: None,
            hostfwd_present: None,
            port_listening: None,
            ssh_reachable: None,
        };
        let out = report.to_string();
        assert!(
            out.contains("no process found"),
            "should show no process:\n{out}"
        );
    }

    #[test]
    fn health_report_stops_at_qemu_not_running() {
        let ssh = SshEngine::new();
        let report = super::check_health(&ssh);
        if !report.qemu_running {
            assert!(report.qemu_pid.is_none());
            assert!(report.hostfwd_present.is_none());
            assert!(report.port_listening.is_none());
            assert!(report.ssh_reachable.is_none());
        }
    }

    #[test]
    fn health_returns_ok_when_ssh_reachable() {
        let ssh = SshEngine::new();
        let report = super::check_health(&ssh);
        let result = super::health(&ssh);
        match report.ssh_reachable {
            Some(true) => assert!(result.is_ok(), "health should pass when ssh is reachable"),
            _ => assert!(
                result.is_err(),
                "health should fail when ssh is unreachable"
            ),
        }
    }

    #[test]
    fn status_message_reports_stopped_without_real_vm() {
        with_temp_state_dir(|_| {
            let ssh = SshEngine::new();
            assert_eq!(
                status_message(&ssh).unwrap(),
                "VM Status: Stopped (No VM is currently running)"
            );
        });
    }

    #[test]
    fn status_message_reports_running_for_live_pid_state() {
        with_temp_state_dir(|_| {
            let ssh = SshEngine::new();

            StateManager::write(
                "vm",
                &VmState {
                    pid: std::process::id(),
                    service_name: "vm".to_string(),
                    log_path: "/tmp/vm.log".to_string(),
                },
            )
            .unwrap();

            assert_eq!(VmProcessController::is_active("vm").unwrap(), "active");
            let msg = status_message(&ssh).unwrap();
            assert!(msg.starts_with("VM Status: Running"));
        });
    }
}
