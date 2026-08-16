use crate::shared::prepare_shared_dir;
use std::{
    env,
    path::{Path, PathBuf},
};

pub struct VmRunner {
    pub path: PathBuf,
    pub env: Vec<(String, String)>,
}

fn target_host() -> String {
    if let Ok(host) = env::var("NIX_TARGET_HOST") {
        if !host.is_empty() {
            return host;
        }
    }
    env::var("NIX_DEFAULT_TARGET_HOST")
        .or_else(|_| env::var("ANGST_HOST"))
        .unwrap_or_else(|_| "vm".to_string())
}

fn repo_root() -> String {
    env::var("ANGST_REPO").unwrap_or_else(|_| {
        env::current_dir()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_else(|_| ".".to_string())
    })
}

/// Resolve the built NixOS VM runner binary, if present.
pub fn find_runner() -> Option<PathBuf> {
    let host = target_host();
    let repo = repo_root();

    let explicit = format!("{repo}/result/bin/run-{host}-vm");
    let fallback = format!("{repo}/result/bin/run-nixos-vm");

    if Path::new(&explicit).exists() {
        Some(PathBuf::from(explicit))
    } else if Path::new(&fallback).exists() {
        Some(PathBuf::from(fallback))
    } else {
        None
    }
}

/// Resolve the built NixOS VM runner and the environment it needs to boot.
/// Only host secret material passed to the guest is the age-key shared dir.
pub fn prepare(headless: bool) -> Result<VmRunner, String> {
    let host = target_host();
    let repo = repo_root();

    let path = find_runner().ok_or_else(|| {
        format!(
            "VM runner not found in result/bin. Build the VM first (e.g. 'nix build .#nixosConfigurations.{host}.config.system.build.vm')."
        )
    })?;

    let shared_dir = prepare_shared_dir(&host)?;

    let disk = env::var("NIX_DISK_IMAGE").unwrap_or_else(|_| format!("{repo}/{host}.qcow2"));
    let qemu_opts = if headless { "-display none" } else { "" };

    let env = vec![
        (
            "SHARED_DIR".to_string(),
            shared_dir.to_string_lossy().into_owned(),
        ),
        ("ANGST_REPO".to_string(), repo),
        ("NIX_DISK_IMAGE".to_string(), disk),
        (
            "QEMU_NET_OPTS".to_string(),
            "hostfwd=tcp::2222-:22".to_string(),
        ),
        ("QEMU_OPTS".to_string(), qemu_opts.to_string()),
        ("NIX_DEFAULT_TARGET_HOST".to_string(), host),
    ];

    Ok(VmRunner { path, env })
}
