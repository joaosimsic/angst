use std::env;
use std::path::Path;

use vm_core::VmConfig;

pub fn read_env_value(_key: &str) -> Option<String> {
    None
}

pub fn target_host() -> String {
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
        .unwrap_or_else(|_| "nixos".to_string())
}

pub fn target_username() -> String {
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

pub fn ensure_vm_profile(host: &str) -> Result<(), String> {
    let repo = env::var("ANGST_REPO")
        .or_else(|_| env::current_dir().map(|p| p.to_string_lossy().to_string()))
        .map_err(|e| format!("Cannot determine repo root: {e}"))?;

    let config_path = format!("{repo}/hosts/{host}/default.nix");

    if !Path::new(&config_path).exists() {
        return Err(format!(
            "Host '{host}' not found.\n\
             Expected config at: {config_path}\n\
             Create it at hosts/{host}/default.nix or set NIX_DEFAULT_TARGET_HOST to a valid host."
        ));
    }

    let output = std::process::Command::new("nix")
        .args([
            "eval",
            "--file",
            &config_path,
            "--raw",
            "--apply",
            "x: if builtins.elem \"vm\" (x.profiles or []) then \"true\" else \"false\"",
        ])
        .output()
        .map_err(|e| format!("Failed to check VM profile: {e}"))?;

    if output.status.success() {
        let result = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if result == "true" {
            return Ok(());
        }
    }

    Err(format!(
        "VM profile not enabled for host '{host}'.\n\
         The 'vm' profile is missing from the profiles list.\n\
         Add \"vm\" to the profiles list in hosts/{host}/default.nix to use VM commands.\n\
         Example: profiles = [ \"base\" \"desktop\" \"development\" \"vm\" ];"
    ))
}
