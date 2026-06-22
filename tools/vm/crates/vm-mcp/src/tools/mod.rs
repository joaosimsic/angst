mod handlers;
mod types;

use crate::protocol::{MCP_PROTOCOL_VERSION, McpReply, McpRequest, McpResponse};
use serde_json::json;
use types::{Tool, get_tools_list};
use vm_core::SshEngine;

fn tool_arguments<'a>(
    params: Option<&'a serde_json::Value>,
    default_args: &'a serde_json::Value,
) -> &'a serde_json::Value {
    params
        .and_then(|p| p.get("arguments").or_else(|| p.get("args")))
        .unwrap_or(default_args)
}

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
            let args = tool_arguments(params, &default_args);

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

#[cfg(test)]
mod tests {
    use super::{handle_tool_execution, tool_arguments};
    use crate::protocol::{MCP_PROTOCOL_VERSION, McpReply, McpRequest};
    use serde_json::{Value, json};

    fn response_result(reply: McpReply) -> Value {
        match reply {
            McpReply::Response(response) => response.result.unwrap(),
            McpReply::Accepted => panic!("expected JSON-RPC response"),
        }
    }

    fn response_error(reply: McpReply) -> Value {
        match reply {
            McpReply::Response(response) => response.error.unwrap(),
            McpReply::Accepted => panic!("expected JSON-RPC response"),
        }
    }

    #[test]
    fn initialize_advertises_mcp_tools_capability() {
        let result = response_result(handle_tool_execution(McpRequest {
            method: "initialize".to_string(),
            params: Some(json!({})),
            id: Some(json!(1)),
        }));

        assert_eq!(result["protocolVersion"], MCP_PROTOCOL_VERSION);
        assert_eq!(result["serverInfo"]["name"], "vm-mcp");
        assert!(result["capabilities"]["tools"].is_object());
    }

    #[test]
    fn initialized_notification_is_accepted_without_body() {
        let reply = handle_tool_execution(McpRequest {
            method: "notifications/initialized".to_string(),
            params: None,
            id: None,
        });

        assert!(matches!(reply, McpReply::Accepted));
    }

    #[test]
    fn tools_list_includes_input_schemas() {
        let result = response_result(handle_tool_execution(McpRequest {
            method: "tools/list".to_string(),
            params: None,
            id: Some(json!(2)),
        }));

        let tools = result["tools"].as_array().unwrap();
        let vm_exec = tools.iter().find(|tool| tool["name"] == "vm_exec").unwrap();
        let vm_status = tools
            .iter()
            .find(|tool| tool["name"] == "vm_status")
            .unwrap();

        assert_eq!(vm_exec["inputSchema"]["required"][0], "command");
        assert_eq!(vm_status["inputSchema"]["type"], "object");
    }

    #[test]
    fn unknown_methods_and_tools_return_json_rpc_errors() {
        let method_error = response_error(handle_tool_execution(McpRequest {
            method: "missing/method".to_string(),
            params: None,
            id: Some(json!(3)),
        }));
        assert_eq!(method_error["code"], -32601);

        let tool_error = response_error(handle_tool_execution(McpRequest {
            method: "tools/call".to_string(),
            params: Some(json!({
                "name": "missing_tool",
                "arguments": {}
            })),
            id: Some(json!(4)),
        }));
        assert_eq!(tool_error["code"], -32602);
    }

    #[test]
    fn tool_arguments_prefers_mcp_arguments_and_accepts_legacy_args() {
        let default_args = json!({});
        let params = json!({
            "arguments": { "command": "echo new" },
            "args": { "command": "echo old" }
        });
        assert_eq!(
            tool_arguments(Some(&params), &default_args)["command"],
            "echo new"
        );

        let legacy_params = json!({
            "args": { "command": "echo old" }
        });
        assert_eq!(
            tool_arguments(Some(&legacy_params), &default_args)["command"],
            "echo old"
        );
    }
}
