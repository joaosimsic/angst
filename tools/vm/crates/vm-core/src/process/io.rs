use crate::process::state::VmState;
use std::{
    fs::{self, File},
    io::BufReader,
    path::PathBuf,
};

pub struct StateManager;

impl StateManager {
    pub fn state_dir() -> PathBuf {
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
