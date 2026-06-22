pub mod protocol;
pub mod server;
pub mod tools;

pub use server::run_server;

pub mod service {
    use serde_json::Value;
    use std::{
        io::{Read, Write},
        net::{SocketAddr, TcpStream},
        time::Duration,
    };
    use vm_core::VmProcessController;

    const SERVICE_NAME: &str = "vm-mcp";
    const DEFAULT_PORT: u16 = 8765;
    const HEALTH_TIMEOUT: Duration = Duration::from_secs(2);

    pub fn start() -> Result<(), String> {
        let exe = std::env::current_exe()
            .map_err(|e| format!("Failed to resolve current executable: {}", e))?;
        let exe = exe.to_string_lossy().into_owned();
        let port = DEFAULT_PORT.to_string();

        VmProcessController::start_command(
            SERVICE_NAME,
            &exe,
            ["mcp", "run-server", "--port", port.as_str()],
        )
    }

    pub fn stop() -> Result<(), String> {
        VmProcessController::stop(SERVICE_NAME)
    }

    pub fn restart() -> Result<(), String> {
        let _ = stop();
        start()
    }

    pub fn status() -> Result<String, String> {
        let process_state = VmProcessController::is_active(SERVICE_NAME)?;

        if process_state != "active" {
            return Ok("inactive".to_string());
        }

        match probe_health(DEFAULT_PORT) {
            Ok(()) => Ok("healthy (process active, /health ok, VM reachable)".to_string()),
            Err(err) => Ok(format!(
                "degraded (process active, /health failed: {})",
                err
            )),
        }
    }

    pub fn logs(lines: u32) -> Result<(), String> {
        VmProcessController::stream_logs(SERVICE_NAME, lines)
    }

    fn probe_health(port: u16) -> Result<(), String> {
        let addr = SocketAddr::from(([127, 0, 0, 1], port));
        let mut stream =
            TcpStream::connect_timeout(&addr, HEALTH_TIMEOUT).map_err(|e| e.to_string())?;

        stream
            .set_read_timeout(Some(HEALTH_TIMEOUT))
            .map_err(|e| e.to_string())?;
        stream
            .set_write_timeout(Some(HEALTH_TIMEOUT))
            .map_err(|e| e.to_string())?;

        let request = format!(
            "GET /health HTTP/1.1\r\nHost: 127.0.0.1:{}\r\nAccept: application/json\r\nConnection: close\r\n\r\n",
            port
        );

        stream
            .write_all(request.as_bytes())
            .map_err(|e| e.to_string())?;

        let mut response = String::new();
        stream
            .read_to_string(&mut response)
            .map_err(|e| e.to_string())?;

        classify_health_response(&response)
    }

    fn classify_health_response(response: &str) -> Result<(), String> {
        let (head, body) = response
            .split_once("\r\n\r\n")
            .ok_or_else(|| "malformed HTTP response".to_string())?;
        let status_line = head.lines().next().unwrap_or_default();

        if !status_line.contains(" 200 ") {
            return Err(status_line.to_string());
        }

        let payload: Value =
            serde_json::from_str(body).map_err(|e| format!("invalid health JSON: {}", e))?;

        if payload.get("status").and_then(Value::as_str) != Some("ok") {
            return Err(format!("unexpected status: {}", payload["status"]));
        }

        if payload.get("VmReachable").and_then(Value::as_bool) != Some(true) {
            let details = payload
                .get("details")
                .and_then(Value::as_str)
                .unwrap_or("VM is not reachable");
            return Err(details.to_string());
        }

        Ok(())
    }

    #[cfg(test)]
    mod tests {
        use super::classify_health_response;

        #[test]
        fn accepts_healthy_response() {
            let response = concat!(
                "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n",
                r#"{"status":"ok","VmReachable":true,"details":"healthy"}"#
            );

            assert!(classify_health_response(response).is_ok());
        }

        #[test]
        fn rejects_unreachable_vm_response() {
            let response = concat!(
                "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n",
                r#"{"status":"ok","VmReachable":false,"details":"ssh timeout"}"#
            );

            let err = classify_health_response(response).unwrap_err();
            assert!(err.contains("ssh timeout"));
        }

        #[test]
        fn rejects_non_success_http_response() {
            let response = "HTTP/1.1 503 Service Unavailable\r\n\r\nunavailable";

            let err = classify_health_response(response).unwrap_err();
            assert!(err.contains("503"));
        }
    }
}
