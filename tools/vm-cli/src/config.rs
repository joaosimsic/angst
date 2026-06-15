pub fn vm_ssh_port() -> String {
    std::env::var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string())
}

pub fn vm_ssh_user() -> String {
    std::env::var("VM_SSH_USER").unwrap_or_else(|_| "joao".to_string())
}

pub fn vm_ssh_identity() -> String {
    std::env::var("VM_SSH_IDENTITY").unwrap_or_else(|_| {
        std::env::var("HOME")
            .map(|home| format!("{home}/.ssh/id_ed25519"))
            .unwrap_or_else(|_| "~/.ssh/id_ed25519".to_string())
    })
}
