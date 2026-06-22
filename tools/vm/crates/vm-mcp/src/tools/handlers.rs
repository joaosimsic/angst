use serde_json::{Value, json};
use vm_core::{SshEngine, VmProcessController};

pub(crate) fn run_vm_exec(ssh: &SshEngine, args: &Value) -> Value {
    let cmd = args.get("command").and_then(|v| v.as_str()).unwrap_or("");

    match ssh.exec(cmd) {
        Ok((code, stdout, stderr)) => json!({
            "content": [{
                "type": "text",
                "text": format!("Exit code: {}\n\nStdout:\n{}\n\nStderr:\n{}", code, stdout, stderr)
            }]
        }),
        Err(e) => json!({
            "content": [{ "type": "text", "text": format!("Error: {}", e) }],
            "isError": true,
        }),
    }
}

pub(crate) fn run_vm_status(ssh: &SshEngine) -> Value {
    let state = VmProcessController::is_active("vm").unwrap_or_else(|_| "inactive".to_string());
    let is_active = state == "active";

    let text = if is_active {
        match ssh.exec("echo ok") {
            Ok(_) => "VM is running and accepting SSH connections",
            Err(_) => "VM systemd unit is active but SSH is unreachable",
        }
    } else {
        "VM systemd unit is stopped"
    };

    json!({ "content": [{ "type": "text", "text": text}] })
}

pub(crate) fn run_vm_restart(headless: bool) -> Value {
    match VmProcessController::restart("vm", headless) {
        Ok(_) => json!({ "content": [{ "type": "text", "text": "VM restarting" }] }),
        Err(e) => json!({
            "content": [{ "type": "text", "text": format!("Restart failed: {}", e) }],
            "isError": true,
        }),
    }
}
