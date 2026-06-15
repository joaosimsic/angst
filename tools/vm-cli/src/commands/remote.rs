use std::os::unix::process::CommandExt;
use std::process::Command;

use crate::config::{vm_ssh_identity, vm_ssh_port, vm_ssh_user};
use crate::ssh::run;

fn ssh_base_args() -> Vec<String> {
    vec![
        "-o".to_string(),
        "StrictHostKeyChecking=no".to_string(),
        "-o".to_string(),
        "UserKnownHostsFile=/dev/null".to_string(),
        "-o".to_string(),
        "IdentitiesOnly=yes".to_string(),
        "-i".to_string(),
        vm_ssh_identity(),
        "-p".to_string(),
        vm_ssh_port(),
        format!("{}@localhost", vm_ssh_user()),
    ]
}

pub fn ssh(args: &[String]) -> Result<(), String> {
    let mut ssh_args = ssh_base_args();
    ssh_args.extend(args.iter().cloned());
    let err = Command::new("ssh").args(&ssh_args).exec();
    Err(format!("failed to exec ssh: {err}"))
}

pub fn exec(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("'exec' requires a command".into());
    }
    let mut ssh_args = ssh_base_args();
    ssh_args.extend(args.iter().cloned());
    run(
        "ssh",
        &ssh_args.iter().map(|s| s.as_str()).collect::<Vec<_>>(),
    )
}

pub fn copy_to(src: &str, dest: Option<&str>) -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let dest = dest.unwrap_or(".");
    let target = format!("{user}@localhost:{dest}");
    run(
        "scp",
        &[
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "IdentitiesOnly=yes",
            "-i",
            &vm_ssh_identity(),
            "-P",
            &port,
            src,
            &target,
        ],
    )
}

pub fn copy_from(src: &str, dest: Option<&str>) -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let dest = dest.unwrap_or(".");
    let source = format!("{user}@localhost:{src}");
    run(
        "scp",
        &[
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "IdentitiesOnly=yes",
            "-i",
            &vm_ssh_identity(),
            "-P",
            &port,
            &source,
            dest,
        ],
    )
}
