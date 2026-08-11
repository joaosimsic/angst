use tokio::process::Command;
use vm_core::{SshEngine, VmConfig, VmProcessController};

use super::start::start;
use super::target::{ensure_vm_profile, target_host};

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

fn vm_ssh_reachable(ssh: &SshEngine) -> bool {
    VmProcessController::is_active("vm").as_deref() == Ok("active") && ssh.exec("true").is_ok()
}

pub async fn ssh(
    ssh: &SshEngine,
    auto_start: bool,
    tty: bool,
    args: Vec<String>,
) -> Result<(), String> {
    let host = target_host();
    ensure_vm_profile(&host)?;
    if auto_start && !vm_ssh_reachable(ssh) {
        println!("VM not running. Starting headless...");
        start(ssh, true).await?;
    }

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

    let status = cmd.status().await.map_err(|e| e.to_string())?;

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
