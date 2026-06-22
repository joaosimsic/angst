use crate::process::state::VmState;
use std::{
    fs::{self, File},
    io::BufReader,
    path::PathBuf,
};

#[cfg(test)]
use std::{
    sync::{Mutex, OnceLock},
    time::{SystemTime, UNIX_EPOCH},
};

pub struct StateManager;

#[cfg(test)]
static ENV_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

#[cfg(test)]
pub(crate) fn with_temp_state_dir(test: impl FnOnce(&std::path::Path)) {
    let _guard = ENV_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap();
    let dir = std::env::temp_dir().join(format!(
        "vm-state-test-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));

    unsafe {
        std::env::set_var(StateManager::STATE_DIR_ENV, &dir);
    }

    test(&dir);

    unsafe {
        std::env::remove_var(StateManager::STATE_DIR_ENV);
    }
    let _ = fs::remove_dir_all(dir);
}

impl StateManager {
    const STATE_DIR_ENV: &str = "VM_STATE_DIR";

    pub fn state_dir() -> PathBuf {
        if let Ok(path) = std::env::var(Self::STATE_DIR_ENV) {
            return PathBuf::from(path);
        }

        let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/tmp"));
        path.push(".local/state/vm");
        path
    }

    pub fn state_file(service: &str) -> PathBuf {
        Self::state_dir().join(format!("{}.json", service))
    }

    pub fn write(service: &str, state: &VmState) -> Result<(), String> {
        let dir = Self::state_dir();

        fs::create_dir_all(&dir).map_err(|e| format!("Failed to create state directory: {}", e))?;

        let path = Self::state_file(service);
        let file =
            File::create(&path).map_err(|e| format!("Failed to create state file: {}", e))?;

        serde_json::to_writer_pretty(file, state)
            .map_err(|e| format!("Failed to serialize VM state: {}", e))?;

        Ok(())
    }

    pub fn read(service: &str) -> Option<VmState> {
        let path = Self::state_file(service);

        if !path.exists() {
            return None;
        }

        let file = File::open(path).ok()?;
        let reader = BufReader::new(file);

        serde_json::from_reader(reader).ok()
    }

    pub fn clear(service: &str) {
        let path = Self::state_file(service);

        if path.exists() {
            let _ = fs::remove_file(path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{StateManager, with_temp_state_dir};
    use crate::process::state::VmState;

    #[test]
    fn state_dir_can_be_overridden_for_tests() {
        with_temp_state_dir(|dir| {
            assert_eq!(StateManager::state_dir(), dir);
        });
    }

    #[test]
    fn writes_reads_and_clears_service_state() {
        with_temp_state_dir(|_| {
            let state = VmState {
                pid: 1234,
                service_name: "vm-test".to_string(),
                log_path: "/tmp/vm-test.log".to_string(),
            };

            StateManager::write("vm-test", &state).unwrap();

            let read = StateManager::read("vm-test").unwrap();
            assert_eq!(read.pid, 1234);
            assert_eq!(read.service_name, "vm-test");
            assert_eq!(read.log_path, "/tmp/vm-test.log");

            StateManager::clear("vm-test");
            assert!(StateManager::read("vm-test").is_none());
        });
    }
}
