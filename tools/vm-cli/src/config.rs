pub fn vm_ssh_port() -> String {
    std::env::var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string())
}

pub fn vm_ssh_user() -> String {
    std::env::var("VM_SSH_USER").unwrap_or_else(|_| "joao".to_string())
}
