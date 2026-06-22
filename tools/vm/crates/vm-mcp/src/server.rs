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

#[cfg(test)]
mod tests {
    use super::{mcp_endpoint, mcp_stream_endpoint};
    use axum::{
        Json,
        body::to_bytes,
        http::{HeaderMap, HeaderValue, StatusCode, header},
    };
    use serde_json::{Value, json};

    async fn response_body_json(response: axum::response::Response) -> Value {
        let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        serde_json::from_slice(&bytes).unwrap()
    }

    #[tokio::test]
    async fn post_initialize_returns_json_response() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::ACCEPT,
            HeaderValue::from_static("application/json, text/event-stream"),
        );

        let response = mcp_endpoint(
            headers,
            Json(crate::protocol::McpRequest {
                method: "initialize".to_string(),
                params: Some(json!({})),
                id: Some(json!(1)),
            }),
        )
        .await;

        assert_eq!(response.status(), StatusCode::OK);
        let body = response_body_json(response).await;
        assert_eq!(body["result"]["serverInfo"]["name"], "vm-mcp");
    }

    #[tokio::test]
    async fn notification_returns_accepted_without_body() {
        let response = mcp_endpoint(
            HeaderMap::new(),
            Json(crate::protocol::McpRequest {
                method: "notifications/initialized".to_string(),
                params: None,
                id: None,
            }),
        )
        .await;

        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        assert!(bytes.is_empty());
    }

    #[tokio::test]
    async fn rejects_clients_that_do_not_accept_json() {
        let mut headers = HeaderMap::new();
        headers.insert(header::ACCEPT, HeaderValue::from_static("text/plain"));

        let response = mcp_endpoint(
            headers,
            Json(crate::protocol::McpRequest {
                method: "tools/list".to_string(),
                params: None,
                id: Some(json!(2)),
            }),
        )
        .await;

        assert_eq!(response.status(), StatusCode::NOT_ACCEPTABLE);
    }

    #[tokio::test]
    async fn get_stream_endpoint_is_sse_compatible() {
        let response = mcp_stream_endpoint().await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers().get(header::CONTENT_TYPE).unwrap(),
            "text/event-stream"
        );
    }
}
