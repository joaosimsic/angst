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
