use serde_json::{json, Value};

pub(crate) enum Tool {
    VmExec,
    VmStatus,
    VmRestart,
    Unknown(String),
}

impl From<&str> for Tool {
    fn from(s: &str) -> Self {
        match s {
            "vm_exec" => Tool::VmExec,
            "vm_status" => Tool::VmStatus,
            "vm_restart" => Tool::VmRestart,
            _ => Tool::Unknown(s.to_string()),
        }
    }
}

pub(crate) fn get_tools_list() -> Value {
    json!({
        "tools": [
            { "name": "vm_exec", "description": "Execute a command inside the NixOS VM via SSH" },
            { "name": "vm_status", "description": "Check if the VM is running and accessible" },
            { "name": "vm_restart", "description": "Trigger local VM systemd restart action" }
        ]
    })
}
