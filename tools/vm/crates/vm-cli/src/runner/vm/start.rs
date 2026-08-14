use std::env;
use std::time::Duration;

use tokio::{process::Command, time};
use vm_core::{SshEngine, VmProcessController, runner};

use super::health::{any_qemu_running, detect_display, kill_stale_qemu};
use super::target::{ensure_vm_profile, read_env_value, target_host, target_username};

pub async fn start(ssh: &SshEngine, headless: bool) -> Result<(), String> {
    let host = target_host();
    ensure_vm_profile(&host)?;
    let disk = format!("{}.qcow2", host);
    kill_stale_qemu(&disk);

    let effective_headless = headless || !detect_display();

    if runner::find_runner().is_none() {
        println!(
            "VM image not found. Building NixOS VM system image for host '{}'...",
            host
        );

        let username = target_username();
        let password = env::var("ANGST_PASSWORD")
            .ok()
            .filter(|p| !p.is_empty())
            .or_else(|| read_env_value("PASSWORD"));

        let mut cmd = Command::new("nix");
        cmd.args([
            "build",
            "--refresh",
            "--no-write-lock-file",
            &format!(".#nixosConfigurations.{host}.config.system.build.vm"),
        ])
        .env("ANGST_USERNAME", &username);

        if let Some(ref p) = password {
            cmd.env("ANGST_PASSWORD", p);
        }

        let output = cmd
            .output()
            .await
            .map_err(|e| format!("Failed to run nix build: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(format!(
                "Nix compilation of the target VM profile failed.\n{}",
                stderr.trim()
            ));
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
