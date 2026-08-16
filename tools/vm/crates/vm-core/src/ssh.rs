use crate::config::VmConfig;
use ssh2::Session;
use std::{
    fs::{File, metadata},
    io::{Read, Write},
    net::TcpStream,
    path::{Path, PathBuf},
};

pub struct SshEngine {
    config: VmConfig,
}

fn ensure_pub_key(key: &Path, pub_key: &Path) -> Result<(), String> {
    let output = std::process::Command::new("ssh-keygen")
        .args(["-y", "-f"])
        .arg(key)
        .output()
        .map_err(|e| format!("Failed to run ssh-keygen to derive public key: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "Failed to derive public key {} from {}: {}",
            pub_key.display(),
            key.display(),
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }

    let pubkey = String::from_utf8_lossy(&output.stdout);
    std::fs::write(pub_key, pubkey.trim_end_matches('\n')).map_err(|e| {
        format!(
            "Failed to write derived public key {}: {}",
            pub_key.display(),
            e
        )
    })?;
    Ok(())
}

impl SshEngine {
    pub fn new() -> Self {
        Self {
            config: VmConfig::load(),
        }
    }

    fn identity_paths(&self) -> (PathBuf, PathBuf) {
        let key = PathBuf::from(&self.config.ssh_identity);
        let mut pub_key = key.clone();
        pub_key.set_extension("pub");
        (key, pub_key)
    }

    fn connect(&self) -> Result<Session, String> {
        let addr = format!("127.0.0.1:{}", self.config.ssh_port);

        let tcp = TcpStream::connect(&addr).map_err(|e| {
            format!(
                "Failed to connect to VM port {}: {}",
                self.config.ssh_port, e
            )
        })?;

        let mut sess = Session::new().unwrap();

        sess.set_tcp_stream(tcp);
        sess.handshake()
            .map_err(|e| format!("SSH handshake failed: {}", e))?;

        let (key, pub_key) = self.identity_paths();

        if !key.exists() {
            return Err(format!(
                "VM SSH identity not found at {}. Provision it with the shared scope key (angst-provision-ssh-key) or set VM_SSH_IDENTITY.",
                key.display()
            ));
        }

        if !pub_key.exists() {
            ensure_pub_key(&key, &pub_key)?;
        }

        sess.userauth_pubkey_file(
            &self.config.ssh_user,
            Some(pub_key.as_path()),
            key.as_path(),
            None,
        )
        .map_err(|e| {
            format!(
                "SSH pubkey auth failed for user {} with {}: {}",
                self.config.ssh_user,
                key.display(),
                e
            )
        })?;

        Ok(sess)
    }

    pub fn exec(&self, command: &str) -> Result<(i32, String, String), String> {
        let sess = self.connect()?;

        let mut channel = sess.channel_session().map_err(|e| e.to_string())?;
        channel.exec(command).map_err(|e| e.to_string())?;

        let mut stdout = String::new();
        let mut stderr = String::new();

        channel.read_to_string(&mut stdout).ok();
        channel.stderr().read_to_string(&mut stderr).ok();

        channel.wait_close().ok();

        let exit_code = channel.exit_status().unwrap_or(0);

        Ok((exit_code, stdout, stderr))
    }

    pub fn copy_to(&self, local_path: &str, remote_path: &str) -> Result<(), String> {
        let sess = self.connect()?;

        let metadata = metadata(local_path).map_err(|e| e.to_string())?;

        let mut file = File::open(local_path).map_err(|e| e.to_string())?;

        let mut remote_file = sess
            .scp_send(Path::new(remote_path), 0o644, metadata.len(), None)
            .map_err(|e| e.to_string())?;

        let mut buf = Vec::new();

        file.read_to_end(&mut buf).map_err(|e| e.to_string())?;
        remote_file.write_all(&buf).map_err(|e| e.to_string())?;

        Ok(())
    }

    pub fn copy_from(&self, remote_path: &str, local_path: &str) -> Result<(), String> {
        let sess = self.connect()?;

        let (mut remote_file, stat) = sess
            .scp_recv(Path::new(remote_path))
            .map_err(|e| e.to_string())?;

        let mut local_file = File::create(local_path).map_err(|e| e.to_string())?;

        let mut buf = vec![0; stat.size() as usize];

        remote_file
            .read_exact(&mut buf)
            .map_err(|e| e.to_string())?;
        local_file.write_all(&buf).map_err(|e| e.to_string())?;

        Ok(())
    }
}
