use std::env;
use std::fs;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

fn resolve_host_shell() -> String {
    if let Ok(shells) = env::var("SHELL_ENABLED_SHELLS") {
        for path in shells.split(':') {
            if !path.is_empty() && Path::new(path).is_file() {
                return path.to_string();
            }
        }
    }
    env::var("SHELL").unwrap_or_else(|_| "/bin/bash".to_string())
}

fn home() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .expect("HOME must be set")
}

fn remove_if_exists(path: &Path) {
    if fs::symlink_metadata(path).is_ok() {
        let _ = fs::remove_file(path);
        let _ = fs::remove_dir_all(path);
    }
}

fn setup_treesitter() {
    let ts_dir = home().join(".local/share/tree-sitter");

    let src_parsers = env::var("SHELL_TS_PARSERS").ok();
    let src_queries = env::var("SHELL_TS_QUERIES").ok();

    if src_parsers.is_none() && src_queries.is_none() {
        return;
    }

    let _ = fs::create_dir_all(&ts_dir);

    let parser_link = ts_dir.join("parser");
    let queries_link = ts_dir.join("queries");

    if let Some(p) = &src_parsers {
        remove_if_exists(&parser_link);
        let _ = std::os::unix::fs::symlink(p, &parser_link);
    }
    if let Some(q) = &src_queries {
        remove_if_exists(&queries_link);
        let _ = std::os::unix::fs::symlink(q, &queries_link);
    }
}

fn read_env_value(key: &str) -> Option<String> {
    let paths = [
        env::var("ANGST_REPO").ok().map(|p| Path::new(&p).join("user.env")),
        env::current_dir().ok().map(|d| d.join("user.env")),
    ];
    for path in paths.iter().flatten() {
        if let Some(val) = read_from_env_file(path, key) {
            return Some(val);
        }
    }
    None
}

fn read_from_env_file(path: &Path, key: &str) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = trimmed.split_once('=') {
            if k.trim() == key {
                let val = v.trim();
                if !val.is_empty() {
                    return Some(strip_quotes(val).to_string());
                }
            }
        }
    }
    None
}

fn strip_quotes(s: &str) -> &str {
    s.strip_prefix('\'').and_then(|s| s.strip_suffix('\''))
        .or_else(|| s.strip_prefix('"').and_then(|s| s.strip_suffix('"')))
        .unwrap_or(s)
}

pub fn enter(mode: super::commands::Commands) -> ! {
    let (path_key, nix_shell) = match mode {
        super::commands::Commands::Dev => ("SHELL_DEV_PATH", "dev"),
        super::commands::Commands::Safe => ("SHELL_SAFE_PATH", "safe"),
    };

    let extra_path = env::var(path_key).unwrap_or_else(|_| {
        eprintln!(
            "error: {} not set — was this binary built by Nix?",
            path_key
        );
        std::process::exit(1);
    });

    setup_treesitter();

    let current_path = env::var("PATH").unwrap_or_default();
    let new_path = format!("{}:{}", extra_path, current_path);

    let shell = resolve_host_shell();

    let entry = env::var("SHELL_DEV_ENTRY").ok();
    let cmd = if nix_shell == "dev" {
        entry.unwrap_or_else(|| shell.clone())
    } else {
        shell.clone()
    };

    let err = Command::new(&cmd)
        .env("PATH", &new_path)
        .env("IN_NIX_SHELL", "impure")
        .env("name", nix_shell)
        .env("SHELL_MODE", nix_shell)
        .env("ORIGINAL_SHELL", &shell)
        .exec();

    eprintln!("error: failed to exec {}: {}", cmd, err);
    std::process::exit(1);
}
