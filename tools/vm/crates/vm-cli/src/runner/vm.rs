use std::time::Duration;
use tokio::time;
use vm_core::{SshEngine, SystemdController};

pub async fn start(ssh: &SshEngine) -> Result<(), String> {
    SystemdController::start("vm")?;
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
    let active = SystemdController::is_active("vm")?;

    println!("VM service active status: {}", active);

    Ok(())
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
