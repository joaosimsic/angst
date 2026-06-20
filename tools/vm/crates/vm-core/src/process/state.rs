use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct VmState {
    pub pid: u32,
    pub service_name: String,
    pub log_path: String,
}

