use crate::config::{vm_ssh_port, vm_ssh_user};
use crate::ssh::wait_for_ssh;
use crate::systemd;

pub fn start() -> Result<(), String> {
    eprintln!("Starting VM...");
    systemd::service_start("vm")?;
    wait_for_ssh(&vm_ssh_port(), &vm_ssh_user(), 60)
}

pub fn stop() -> Result<(), String> {
    eprintln!("Stopping VM...");
    systemd::service_stop("vm")?;
    eprintln!("VM stopped");
    Ok(())
}

pub fn restart() -> Result<(), String> {
    eprintln!("Restarting VM...");
    systemd::service_restart("vm")?;
    wait_for_ssh(&vm_ssh_port(), &vm_ssh_user(), 60)
}

pub fn status() -> Result<(), String> {
    let port = vm_ssh_port();
    if systemd::service_is_active("vm")? {
        eprintln!("VM is running (SSH reachable on port {port})");
        Ok(())
    } else {
        Err(format!(
            "VM is not running (SSH not reachable on port {port})"
        ))
    }
}

pub fn logs(lines: u32) -> Result<(), String> {
    systemd::service_logs("vm", lines)
}
