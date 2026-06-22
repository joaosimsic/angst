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

    VmProcessController::start("vm", headless)?;

    println!("VM Started! Validating connection status...");

    for _ in 0..30 {
        if ssh.exec("true").is_ok() {
            println!("VM was initialized and ready via SSH");
            return Ok(());
        }

        time::sleep(Duration::from_secs(1)).await;
    }

    Err("VM started but SSH connection timed out.".to_string())
}

pub fn status() -> Result<(), String> {
    match VmProcessController::is_active("vm") {
        Ok(state) => {
            if state == "active" {
                println!("VM Status: Running");
            } else if state == "inactive" {
                println!("VM Status: Stopped (No VM is currently running)");
            } else {
                println!("VM Status: {}", state);
            }
            Ok(())
        }
        Err(e) => {
            if e.contains("not found") || e.contains("failed to load") {
                return Err("VM service units are not installed. Run './scripts/setup-tools.sh --skip-vm-build' to install them.".to_string());
            }
            Err(format!("Failed to fetch VM status: {}", e))
        }
    }
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
        .arg(format!("{}@127.0.0.1", config.ssh_user));

    if !args.is_empty() {
        cmd.args(args);
    }

    let status = cmd.status().map_err(|e| e.to_string())?;

    if !status.success() {
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
