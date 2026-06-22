mod handlers;
mod types;

use crate::protocol::{MCP_PROTOCOL_VERSION, McpReply, McpRequest, McpResponse};
use serde_json::json;
use types::{Tool, get_tools_list};
use vm_core::SshEngine;

pub fn handle_tool_execution(payload: McpRequest) -> McpReply {
    let id = payload.id;

    match payload.method.as_str() {
        "initialize" => McpReply::Response(McpResponse::success(
            id,
            json!({
                "protocolVersion": MCP_PROTOCOL_VERSION,
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "vm-mcp",
                    "version": env!("CARGO_PKG_VERSION")
                }
            }),
        )),
        "notifications/initialized" => McpReply::Accepted,
        "tools/list" => McpReply::Response(McpResponse::success(id, get_tools_list())),
        "tools/call" => {
            let params = payload.params.as_ref();
            let tool_name = params
                .and_then(|p| p.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            let default_args = json!({});
            let args = params
                .and_then(|p| p.get("arguments").or_else(|| p.get("args")))
                .unwrap_or(&default_args);

            let ssh = SshEngine::new();

            match Tool::from(tool_name) {
                Tool::VmExec => {
                    McpReply::Response(McpResponse::success(id, handlers::run_vm_exec(&ssh, args)))
                }
                Tool::VmStatus => {
                    McpReply::Response(McpResponse::success(id, handlers::run_vm_status(&ssh)))
                }
                Tool::VmRestart => {
                    let is_headless = args
                        .get("headless")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);

                    McpReply::Response(McpResponse::success(
                        id,
                        handlers::run_vm_restart(is_headless),
                    ))
                }
                Tool::Unknown(name) => McpReply::Response(McpResponse::error(
                    id,
                    -32602,
                    format!("Tool '{}' not found", name),
                )),
            }
        }
        _ if id.is_none() => McpReply::Accepted,
        _ => McpReply::Response(McpResponse::error(id, -32601, "Method not found")),
    }
}
