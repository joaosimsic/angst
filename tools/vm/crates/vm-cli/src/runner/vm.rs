use std::time::Duration;
use tokio::time;
use vm_core::{SshEngine, VmProcessController};

pub async fn start(ssh: &SshEngine) -> Result<(), String> {
    VmProcessController::start("vm")?;
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

pub fn ssh(ssh: &SshEngine, args: Vec<String>) -> Result<(), String> {
    let full_cmd = if args.is_empty() {
        "bash".to_string()
    } else {
        args.join(" ")
    };

    let (_, stdout, stderr) = ssh.exec(&full_cmd)?;

    print!("{}", stdout);
    eprint!("{}", stderr);

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
