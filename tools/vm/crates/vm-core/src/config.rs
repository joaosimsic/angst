use std::env::var;

pub struct VmConfig {
    pub ssh_port: String,
    pub ssh_user: String,
    pub default_host: String,
    pub ssh_identity: String,
}

impl VmConfig {
    pub fn load() -> Self {
        Self {
            ssh_port: var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string()),
            ssh_user: Self::resolve_username(),
            default_host: var("NIX_DEFAULT_TARGET_HOST").unwrap_or_else(|_| "personal".to_string()),
            ssh_identity: Self::resolve_identity(),
        }
    }

    fn resolve_identity() -> String {
        if let Ok(id) = var("VM_SSH_IDENTITY") {
            if !id.is_empty() {
                return id;
            }
        }
        let home = var("HOME").unwrap_or_else(|_| "~".to_string());
        format!("{home}/.ssh/id_ed25519")
    }

    fn resolve_username() -> String {
        if let Ok(user) = var("VM_SSH_USER") {
            if !user.is_empty() {
                return user;
            }
        }
        if let Ok(user) = var("ANGST_USERNAME") {
            if !user.is_empty() {
                return user;
            }
        }
        "joao".to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::VmConfig;
    use std::sync::{Mutex, OnceLock};

    static ENV_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

    #[test]
    fn loads_defaults_when_environment_is_unset() {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        unsafe {
            std::env::remove_var("VM_SSH_PORT");
            std::env::remove_var("VM_SSH_USER");
            std::env::remove_var("ANGST_USERNAME");
            std::env::remove_var("NIX_DEFAULT_TARGET_HOST");
            std::env::remove_var("VM_SSH_IDENTITY");
            std::env::set_var("HOME", "/home/test");
        }

        let config = VmConfig::load();

        assert_eq!(config.ssh_port, "2222");
        assert_eq!(config.ssh_user, "joao");
        assert_eq!(config.default_host, "personal");
        assert_eq!(config.ssh_identity, "/home/test/.ssh/id_ed25519");

        unsafe {
            std::env::remove_var("HOME");
        }
    }

    #[test]
    fn loads_environment_overrides() {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        unsafe {
            std::env::set_var("VM_SSH_PORT", "2200");
            std::env::set_var("VM_SSH_USER", "ci");
            std::env::set_var("NIX_DEFAULT_TARGET_HOST", "ci-host");
            std::env::set_var("VM_SSH_IDENTITY", "/keys/custom");
        }

        let config = VmConfig::load();

        assert_eq!(config.ssh_port, "2200");
        assert_eq!(config.ssh_user, "ci");
        assert_eq!(config.default_host, "ci-host");
        assert_eq!(config.ssh_identity, "/keys/custom");

        unsafe {
            std::env::remove_var("VM_SSH_PORT");
            std::env::remove_var("VM_SSH_USER");
            std::env::remove_var("NIX_DEFAULT_TARGET_HOST");
            std::env::remove_var("VM_SSH_IDENTITY");
        }
    }
}
