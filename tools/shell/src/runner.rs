use std::env;
use std::fs;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

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

pub fn enter(mode: super::commands::Commands) -> ! {
    let (path_key, nix_shell) = match mode {
        super::commands::Commands::Dev => ("SHELL_DEV_PATH", "dev"),
        super::commands::Commands::Safe => ("SHELL_SAFE_PATH", "safe"),
    };

    let extra_path = env::var(path_key).unwrap_or_else(|_| {
        eprintln!("error: {} not set — was this binary built by Nix?", path_key);
        std::process::exit(1);
    });

    setup_treesitter();

    let current_path = env::var("PATH").unwrap_or_default();
    let new_path = format!("{}:{}", extra_path, current_path);

    let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/bash".to_string());

    let err = Command::new(&shell)
        .env("PATH", &new_path)
        .env("IN_NIX_SHELL", nix_shell)
        .env("SHELL_MODE", nix_shell)
        .exec();

    eprintln!(
        "error: failed to exec {}: {}",
        shell,
        err
    );
    std::process::exit(1);
}
