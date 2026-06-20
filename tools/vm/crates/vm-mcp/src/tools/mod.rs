mod handlers;
mod types;

use crate::protocol::{McpRequest, McpResponse};
use serde_json::json;
use types::{get_tools_list, Tool};
use vm_core::SshEngine;

pub fn handle_tool_execution(payload: McpRequest) -> McpResponse {
    let mut response = McpResponse {
        jsonrpc: "2.0".to_string(),
        result: None,
        error: None,
        id: payload.id,
    };

    match payload.method.as_str() {
        "tools/list" => {
            response.result = Some(get_tools_list());
        }
        "tools/call" => {
            let params = payload.params.as_ref();
            let tool_name = params
                .and_then(|p| p.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            let default_args = json!({});
            let args = params.and_then(|p| p.get("args")).unwrap_or(&default_args);

            let ssh = SshEngine::new();

            response.result = match Tool::from(tool_name) {
                Tool::VmExec => Some(handlers::run_vm_exec(&ssh, args)),
                Tool::VmStatus => Some(handlers::run_vm_status(&ssh)),
                Tool::VmRestart => {
                    let is_headless = args
                        .get("headless")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);

                    Some(handlers::run_vm_restart(is_headless))
                }
                Tool::Unknown(name) => {
                    Some(json!({ "error": format!("Tool '{}' not found", name) }))
                }
            }
        }
        _ => {
            response.result = Some(json!({ "error": "Method not implemented" }));
        }
    }

    response
}
