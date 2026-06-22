use crate::{
    protocol::{McpReply, McpRequest},
    tools::handle_tool_execution,
};
use axum::{
    Json, Router,
    http::{HeaderMap, StatusCode, header},
    response::{IntoResponse, Response},
    routing::{get, post},
    serve,
};
use serde_json::{Value, json};
use std::net::SocketAddr;
use tokio::net::TcpListener;
use vm_core::SshEngine;

fn accepts_json(headers: &HeaderMap) -> bool {
    headers
        .get(header::ACCEPT)
        .and_then(|value| value.to_str().ok())
        .map(|accept| accept.contains("application/json") || accept.contains("*/*"))
        .unwrap_or(true)
}

async fn mcp_endpoint(headers: HeaderMap, Json(payload): Json<McpRequest>) -> Response {
    if !accepts_json(&headers) {
        return (
            StatusCode::NOT_ACCEPTABLE,
            "MCP HTTP requests must accept application/json",
        )
            .into_response();
    }

    match handle_tool_execution(payload) {
        McpReply::Response(response) => Json(response).into_response(),
        McpReply::Accepted => StatusCode::ACCEPTED.into_response(),
    }
}

async fn mcp_stream_endpoint() -> Response {
    (
        [(header::CONTENT_TYPE, "text/event-stream")],
        ": vm-mcp stream ready\n\n",
    )
        .into_response()
}

async fn health_endpoint() -> Json<Value> {
    let ssh = SshEngine::new();

    let (reachable, error_message) = match ssh.exec("echo ok") {
        Ok((exit_code, _, _)) => {
            if exit_code != 0 {
                (
                    false,
                    Some(format!("Command exited with status code: {}", exit_code)),
                )
            } else {
                (true, None)
            }
        }
        Err(err) => (false, Some(err)),
    };

    Json(json!({
        "status": "ok",
        "VmReachable": reachable,
        "details": error_message.unwrap_or_else(|| "Connection healthy and fully authenticated".to_string())
    }))
}

pub async fn run_server(port: u16) {
    let app = Router::new()
        .route("/mcp", post(mcp_endpoint).get(mcp_stream_endpoint))
        .route("/health", get(health_endpoint));

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = match TcpListener::bind(addr).await {
        Ok(listener) => listener,
        Err(err) => {
            eprintln!("VM MCP Server failed to listen on http://{}: {}", addr, err);
            return;
        }
    };

    println!("VM MCP Server listening on http://{}", addr);

    if let Err(err) = serve(listener, app).await {
        eprintln!("VM MCP Server stopped with error: {}", err);
    }
}
