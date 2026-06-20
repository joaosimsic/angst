use crate::{
    protocol::{McpRequest, McpResponse},
    tools::handle_tool_execution,
};
use axum::{
    routing::{get, post},
    serve, Json, Router,
};
use serde_json::{json, Value};
use std::net::SocketAddr;
use tokio::net::TcpListener;
use vm_core::SshEngine;

async fn mcp_endpoint(Json(payload): Json<McpRequest>) -> Json<McpResponse> {
    Json(handle_tool_execution(payload))
}

async fn health_endpoint() -> Json<Value> {
    let ssh = SshEngine::new();
    let reachable = ssh.exec("echo ok").is_ok();

    Json(json!({ "status": "ok", "VmReachable": reachable }))
}

pub async fn run_server(port: u16) {
    let app = Router::new()
        .route(
            "/mcp",
            post(mcp_endpoint).get(|| async { "MCP SSE Stream Channel Active" }),
        )
        .route("/health", get(health_endpoint));

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = TcpListener::bind(addr).await.unwrap();

    println!("VM MCP Server listening on http://{}", addr);

    serve(listener, app).await.unwrap();
}
