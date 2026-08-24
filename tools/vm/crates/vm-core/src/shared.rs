use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
};

const AGE_KEY_SOURCES: &[(&str, &str)] = &[
    ("~/.config/age/keys.txt", "age-keys.txt"),
    ("~/.config/age/work-keys.txt", "work-keys.txt"),
];

fn expand_home(path: &str) -> PathBuf {
    if let Some(rest) = path.strip_prefix("~/") {
        let home = std::env::var("HOME").unwrap_or_else(|_| "~".to_string());
        PathBuf::from(home).join(rest)
    } else {
        PathBuf::from(path)
    }
}

/// Shared dir handed to the VM runner via `SHARED_DIR` (mounted at
/// `/tmp/shared` in the guest). Carries only the host age keys — the sole
/// secret material injected from the host into the VM.
pub fn prepare_shared_dir(host: &str) -> Result<PathBuf, String> {
    let base = std::env::var("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
            PathBuf::from(home).join(".local/state")
        });

    let dir = base.join("vm").join("keys").join(host);
    fs::create_dir_all(&dir)
        .map_err(|e| format!("Failed to create VM shared dir {}: {}", dir.display(), e))?;

    let mut found = false;
    for (source, dest) in AGE_KEY_SOURCES {
        let src = expand_home(source);
        if !src.exists() {
            continue;
        }

        let target = dir.join(dest);
        fs::copy(&src, &target).map_err(|e| {
            format!(
                "Failed to copy age key {} to {}: {}",
                src.display(),
                target.display(),
                e
            )
        })?;
        fs::set_permissions(&target, fs::Permissions::from_mode(0o600))
            .map_err(|e| format!("Failed to chmod {}: {}", target.display(), e))?;
        found = true;
    }

    if !found {
        return Err(format!(
            "No host age key found (~/.config/age/keys.txt). The VM cannot decrypt secrets without it."
        ));
    }

    Ok(dir)
}

#[cfg(test)]
mod tests {
    use super::{AGE_KEY_SOURCES, expand_home, prepare_shared_dir};
    use std::{
        fs,
        path::PathBuf,
        sync::{Mutex, OnceLock},
    };

    static ENV_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

    #[test]
    fn expands_tilde_prefix_with_home() {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        unsafe {
            std::env::set_var("HOME", "/home/test");
        }

        assert_eq!(
            expand_home("~/.config/age/keys.txt"),
            PathBuf::from("/home/test/.config/age/keys.txt")
        );

        unsafe {
            std::env::remove_var("HOME");
        }
    }

    #[test]
    fn shared_dir_contains_exactly_age_keys() {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        unsafe {
            std::env::set_var("HOME", "/tmp");
            std::env::set_var("XDG_STATE_HOME", "/tmp/vm-shared-test-state");
        }

        for (source, _) in AGE_KEY_SOURCES {
            let src = expand_home(source);
            if let Some(parent) = src.parent() {
                let _ = fs::create_dir_all(parent);
            }
            let _ = fs::write(&src, b"test-age-key");
        }

        let dir = prepare_shared_dir("test-host").unwrap();

        assert!(dir.join("age-keys.txt").exists());
        assert!(dir.join("work-keys.txt").exists());
        assert!(!dir.join("authorized_keys").exists());

        unsafe {
            std::env::remove_var("HOME");
            std::env::remove_var("XDG_STATE_HOME");
        }
        let _ = fs::remove_dir_all("/tmp/vm-shared-test-state");
    }
}
