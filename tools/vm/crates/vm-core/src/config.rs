use serde::Deserialize;
use serde_json::from_str;
use std::{collections::HashMap, env::var};

#[derive(Debug, Clone, Deserialize)]
pub struct NixVmPaths {
    pub toplevel: String,
    pub runner: String,
    #[serde(rename = "scriptName")]
    pub script_name: String,
}

pub struct VmConfig {
    pub ssh_port: String,
    pub ssh_user: String,
    pub default_host: String,
    pub hosts_map: HashMap<String, NixVmPaths>,
}

impl VmConfig {
    pub fn load() -> Self {
        let hosts_json = var("NIX_VM_HOSTS_MAP").unwrap_or_else(|_| "{}".to_string());
        let hosts_map: HashMap<String, NixVmPaths> = from_str(&hosts_json).unwrap_or_default();

        Self {
            ssh_port: var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string()),
            ssh_user: var("VM_SSH_USER").unwrap_or_else(|_| "joao".to_string()),
            default_host: var("NIX_DEFAULT_TARGET_HOST").unwrap_or_else(|_| "personal".to_string()),
            hosts_map,
        }
    }
}
