pub mod health;
pub mod ssh;
pub mod start;
pub mod target;

pub use health::{check_health, health, HealthReport};
pub use ssh::{exec, ssh, status, status_message};
pub use start::start;

#[cfg(test)]
mod tests {
    use super::{status_message, HealthReport, check_health, health};
    use std::{
        fs,
        sync::{Mutex, OnceLock},
        time::{SystemTime, UNIX_EPOCH},
    };
    use vm_core::{
        SshEngine, VmProcessController, process::io::StateManager, process::state::VmState,
    };

    static ENV_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

    fn with_temp_state_dir(test: impl FnOnce(&std::path::Path)) {
        let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
        let dir = std::env::temp_dir().join(format!(
            "vm-cli-test-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));

        unsafe {
            std::env::set_var("VM_STATE_DIR", &dir);
        }

        test(&dir);

        unsafe {
            std::env::remove_var("VM_STATE_DIR");
        }
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn health_report_formatting_with_all_ok() {
        let report = HealthReport {
            qemu_running: true,
            qemu_pid: Some(12345),
            hostfwd_present: Some(true),
            port_listening: Some(true),
            ssh_reachable: Some(true),
        };
        let out = report.to_string();
        assert!(
            out.contains("QEMU running"),
            "should show qemu check:\n{out}"
        );
        assert!(out.contains("12345"), "should show pid:\n{out}");
        assert!(
            out.contains("hostfwd present"),
            "should show hostfwd:\n{out}"
        );
        assert!(out.contains("0.0.0.0:2222"), "should show port:\n{out}");
        assert!(out.contains("exec true ok"), "should show ssh:\n{out}");
    }

    #[test]
    fn health_report_formatting_with_failures() {
        let report = HealthReport {
            qemu_running: false,
            qemu_pid: None,
            hostfwd_present: None,
            port_listening: None,
            ssh_reachable: None,
        };
        let out = report.to_string();
        assert!(
            out.contains("no process found"),
            "should show no process:\n{out}"
        );
    }

    #[test]
    fn health_report_stops_at_qemu_not_running() {
        let ssh = SshEngine::new();
        let report = check_health(&ssh);
        if !report.qemu_running {
            assert!(report.qemu_pid.is_none());
            assert!(report.hostfwd_present.is_none());
            assert!(report.port_listening.is_none());
            assert!(report.ssh_reachable.is_none());
        }
    }

    #[test]
    fn health_returns_ok_when_ssh_reachable() {
        let ssh = SshEngine::new();
        let report = check_health(&ssh);
        let result = health(&ssh);
        match report.ssh_reachable {
            Some(true) => assert!(result.is_ok(), "health should pass when ssh is reachable"),
            _ => assert!(
                result.is_err(),
                "health should fail when ssh is unreachable"
            ),
        }
    }

    #[test]
    fn status_message_reports_stopped_without_real_vm() {
        with_temp_state_dir(|_| {
            let ssh = SshEngine::new();
            assert_eq!(
                status_message(&ssh).unwrap(),
                "VM Status: Stopped (No VM is currently running)"
            );
        });
    }

    #[test]
    fn status_message_reports_running_for_live_pid_state() {
        with_temp_state_dir(|_| {
            let ssh = SshEngine::new();

            StateManager::write(
                "vm",
                &VmState {
                    pid: std::process::id(),
                    service_name: "vm".to_string(),
                    log_path: "/tmp/vm.log".to_string(),
                },
            )
            .unwrap();

            assert_eq!(VmProcessController::is_active("vm").unwrap(), "active");
            let msg = status_message(&ssh).unwrap();
            assert!(msg.starts_with("VM Status: Running"));
        });
    }
}
