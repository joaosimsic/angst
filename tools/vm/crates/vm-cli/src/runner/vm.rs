use std::{path::Path, time::Duration};
use tokio::{process::Command, time};
use vm_core::{SshEngine, VmConfig, VmProcessController};

pub async fn start(ssh: &SshEngine, headless: bool) -> Result<(), String> {
    let disk_exists = Path::new("result/bin/run-personal-vm").exists();

    if !disk_exists {
        println!("VM image not found. Building NixOS VM system image on host...");

        let build_status = Command::new("nix")
            .args([
                "build",
                ".#nixosConfigurations.personal.config.system.build.vm",
            ])
            .status()
            .await
            .map_err(|e| format!("Failed to run nix build: {}", e))?;

        if !build_status.success() {
            return Err("Nix compilation of the target VM profile failed.".to_string());
        }
    }

    match VmProcessController::start("vm", headless) {
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

    for _ in 0..120 {
        if ssh.exec("true").is_ok() {
            println!("VM was initialized and ready via SSH");
            return Ok(());
        }

        time::sleep(Duration::from_secs(1)).await;
    }

    Err("VM started but SSH connection timed out.".to_string())
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

pub fn ssh(args: Vec<String>) -> Result<(), String> {
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
        .arg("ForwardAgent=yes")
        .arg(format!("{}@127.0.0.1", config.ssh_user));

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
