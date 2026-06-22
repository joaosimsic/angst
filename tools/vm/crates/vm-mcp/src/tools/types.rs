use serde_json::{Value, json};

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
            {
                "name": "vm_exec",
                "description": "Execute a command inside the NixOS VM via SSH",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "Shell command to execute inside the VM"
                        }
                    },
                    "required": ["command"]
                }
            },
            {
                "name": "vm_status",
                "description": "Check if the VM is running and accessible",
                "inputSchema": {
                    "type": "object",
                    "properties": {}
                }
            },
            {
                "name": "vm_restart",
                "description": "Trigger local VM systemd restart action",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "headless": {
                            "type": "boolean",
                            "description": "Whether to start the VM without a graphical display window. Set to true if running tasks programmatically without a desktop UI environment."
                        }
                    }
                }
            }
        ]
    })
}
