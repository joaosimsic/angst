use crate::config::VmConfig;
use ssh2::Session;
use std::{
    fs::{File, metadata},
    io::{Read, Write},
    net::TcpStream,
    path::Path,
};

pub struct SshEngine {
    config: VmConfig,
}

impl SshEngine {
    pub fn new() -> Self {
        Self {
            config: VmConfig::load(),
        }
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
        sess.userauth_agent(&self.config.ssh_user).map_err(|e| {
            format!(
                "SSH Agent auth failed for user {}: {}",
                self.config.ssh_user, e
            )
        })?;

        Ok(sess)
    }

    pub fn exec(&self, command: &str) -> Result<(i32, String, String), String> {
        let sess = self.connect()?;

        let mut channel = sess.channel_session().map_err(|e| e.to_string())?;
        channel.request_auth_agent_forwarding().ok();
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
