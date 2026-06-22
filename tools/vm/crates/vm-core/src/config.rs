use std::env::var;

pub struct VmConfig {
    pub ssh_port: String,
    pub ssh_user: String,
    pub default_host: String,
}

impl VmConfig {
    pub fn load() -> Self {
        Self {
            ssh_port: var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string()),
            ssh_user: var("VM_SSH_USER").unwrap_or_else(|_| "joao".to_string()),
            default_host: var("NIX_DEFAULT_TARGET_HOST").unwrap_or_else(|_| "personal".to_string()),
        }
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
            std::env::remove_var("NIX_DEFAULT_TARGET_HOST");
        }

        let config = VmConfig::load();

        assert_eq!(config.ssh_port, "2222");
        assert_eq!(config.ssh_user, "joao");
        assert_eq!(config.default_host, "personal");
    }

    #[test]
    fn loads_environment_overrides() {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        unsafe {
            std::env::set_var("VM_SSH_PORT", "2200");
            std::env::set_var("VM_SSH_USER", "ci");
            std::env::set_var("NIX_DEFAULT_TARGET_HOST", "ci-host");
        }

        let config = VmConfig::load();

        assert_eq!(config.ssh_port, "2200");
        assert_eq!(config.ssh_user, "ci");
        assert_eq!(config.default_host, "ci-host");

        unsafe {
            std::env::remove_var("VM_SSH_PORT");
            std::env::remove_var("VM_SSH_USER");
            std::env::remove_var("NIX_DEFAULT_TARGET_HOST");
        }
    }
}
