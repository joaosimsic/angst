use clap::{Parser, Subcommand};
use std::io::{self, Write};
use std::os::unix::process::CommandExt;
use std::process::{self, Command};

fn vm_ssh_port() -> String {
    std::env::var("VM_SSH_PORT").unwrap_or_else(|_| "2222".to_string())
}

fn vm_ssh_user() -> String {
    std::env::var("VM_SSH_USER").unwrap_or_else(|_| "joao".to_string())
}

fn run(cmd: &str, args: &[&str]) -> Result<(), String> {
    let status = Command::new(cmd)
        .args(args)
        .status()
        .map_err(|e| format!("failed to execute {cmd}: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{cmd} exited with {status}"))
    }
}

fn run_capture(cmd: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|e| format!("failed to execute {cmd}: {e}"))?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(format!(
            "{cmd} exited with {}\n{}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

fn wait_for_ssh(port: &str, user: &str, timeout_secs: u64) -> Result<(), String> {
    eprintln!("Waiting for SSH...");
    for i in 1..=timeout_secs {
        let status = Command::new("ssh")
            .args([
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "ConnectTimeout=1",
                "-p",
                port,
                &format!("{user}@localhost"),
                "true",
            ])
            .stdout(process::Stdio::null())
            .stderr(process::Stdio::null())
            .status();
        if let Ok(s) = status {
            if s.success() {
                eprintln!("VM is ready (SSH on port {port})");
                return Ok(());
            }
        }
        if i % 10 == 0 || i == 1 {
            eprintln!("  {i}s...");
        }
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
    Err(format!(
        "VM started but SSH is not responding after {timeout_secs}s"
    ))
}

fn cmd_start() -> Result<(), String> {
    eprintln!("Starting VM...");
    run("systemctl", &["--user", "start", "vm"])?;
    wait_for_ssh(&vm_ssh_port(), &vm_ssh_user(), 60)
}

fn cmd_stop() -> Result<(), String> {
    eprintln!("Stopping VM...");
    run("systemctl", &["--user", "stop", "vm"])?;
    eprintln!("VM stopped");
    Ok(())
}

fn cmd_restart() -> Result<(), String> {
    eprintln!("Restarting VM...");
    run("systemctl", &["--user", "restart", "vm"])?;
    wait_for_ssh(&vm_ssh_port(), &vm_ssh_user(), 60)
}

fn cmd_status() -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let status = Command::new("ssh")
        .args([
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "ConnectTimeout=2",
            "-p",
            &port,
            &format!("{user}@localhost"),
            "true",
        ])
        .stdout(process::Stdio::null())
        .stderr(process::Stdio::null())
        .status()
        .map_err(|e| format!("failed to execute ssh: {e}"))?;
    if status.success() {
        eprintln!("VM is running (SSH reachable on port {port})");
        Ok(())
    } else {
        Err(format!(
            "VM is not running (SSH not reachable on port {port})"
        ))
    }
}

fn cmd_logs(lines: u32) -> Result<(), String> {
    let lines = lines.to_string();
    run(
        "journalctl",
        &[
            "--user",
            "-u",
            "vm",
            "-n",
            &lines,
            "--no-pager",
            "-f",
        ],
    )
}

fn cmd_ssh(args: &[String]) -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let mut ssh_args = vec![
        "-o".to_string(),
        "StrictHostKeyChecking=no".to_string(),
        "-p".to_string(),
        port,
        format!("{user}@localhost"),
    ];
    ssh_args.extend(args.iter().cloned());
    let err = Command::new("ssh")
        .args(&ssh_args)
        .exec();
    Err(format!("failed to exec ssh: {err}"))
}

fn cmd_exec(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("'exec' requires a command".into());
    }
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let mut ssh_args = vec![
        "-o".to_string(),
        "StrictHostKeyChecking=no".to_string(),
        "-p".to_string(),
        port,
        format!("{user}@localhost"),
    ];
    ssh_args.extend(args.iter().cloned());
    run("ssh", &ssh_args.iter().map(|s| s.as_str()).collect::<Vec<_>>())
}

fn cmd_copy_to(src: &str, dest: Option<&str>) -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let dest = dest.unwrap_or(".");
    let target = format!("{user}@localhost:{dest}");
    run("scp", &["-o", "StrictHostKeyChecking=no", "-P", &port, src, &target])
}

fn cmd_copy_from(src: &str, dest: Option<&str>) -> Result<(), String> {
    let port = vm_ssh_port();
    let user = vm_ssh_user();
    let dest = dest.unwrap_or(".");
    let source = format!("{user}@localhost:{src}");
    run("scp", &["-o", "StrictHostKeyChecking=no", "-P", &port, &source, dest])
}

fn cmd_mcp_start() -> Result<(), String> {
    eprintln!("Starting MCP server...");
    run("systemctl", &["--user", "start", "vm-mcp"])?;
    eprintln!("MCP server started");
    Ok(())
}

fn cmd_mcp_stop() -> Result<(), String> {
    eprintln!("Stopping MCP server...");
    run("systemctl", &["--user", "stop", "vm-mcp"])?;
    eprintln!("MCP server stopped");
    Ok(())
}

fn cmd_mcp_restart() -> Result<(), String> {
    eprintln!("Restarting MCP server...");
    run("systemctl", &["--user", "restart", "vm-mcp"])?;
    eprintln!("MCP server restarted");
    Ok(())
}

fn cmd_mcp_status() -> Result<(), String> {
    let output = run_capture("systemctl", &["--user", "is-active", "vm-mcp"])?;
    if output.trim() == "active" {
        eprintln!("MCP server is running");
        Ok(())
    } else {
        Err("MCP server is not running".into())
    }
}

fn cmd_mcp_logs(lines: u32) -> Result<(), String> {
    let lines = lines.to_string();
    run(
        "journalctl",
        &[
            "--user",
            "-u",
            "vm-mcp",
            "-n",
            &lines,
            "--no-pager",
            "-f",
        ],
    )
}

#[derive(Parser)]
#[command(name = "vm", about = "VM management CLI", version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the VM
    Start,
    /// Stop the VM
    Stop,
    /// Restart the VM
    Restart,
    /// Check if the VM is running (SSH reachable)
    Status,
    /// Show VM journalctl logs
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
    /// SSH into the VM
    Ssh {
        #[arg(last = true)]
        args: Vec<String>,
    },
    /// Run a command inside the VM via SSH
    Exec {
        #[arg(required = true, last = true)]
        command: Vec<String>,
    },
    /// Copy file from host to VM
    CopyTo {
        src: String,
        dest: Option<String>,
    },
    /// Copy file from VM to host
    CopyFrom {
        src: String,
        dest: Option<String>,
    },
    /// MCP server management
    Mcp {
        #[command(subcommand)]
        action: McpCommands,
    },
}

#[derive(Subcommand)]
enum McpCommands {
    /// Start the MCP server
    Start,
    /// Stop the MCP server
    Stop,
    /// Restart the MCP server
    Restart,
    /// Check MCP server status
    Status,
    /// Show MCP server logs
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Start => cmd_start(),
        Commands::Stop => cmd_stop(),
        Commands::Restart => cmd_restart(),
        Commands::Status => cmd_status(),
        Commands::Logs { lines } => cmd_logs(lines),
        Commands::Ssh { args } => cmd_ssh(&args),
        Commands::Exec { command } => cmd_exec(&command),
        Commands::CopyTo { src, dest } => cmd_copy_to(&src, dest.as_deref()),
        Commands::CopyFrom { src, dest } => cmd_copy_from(&src, dest.as_deref()),
        Commands::Mcp { action } => match action {
            McpCommands::Start => cmd_mcp_start(),
            McpCommands::Stop => cmd_mcp_stop(),
            McpCommands::Restart => cmd_mcp_restart(),
            McpCommands::Status => cmd_mcp_status(),
            McpCommands::Logs { lines } => cmd_mcp_logs(lines),
        },
    };

    if let Err(e) = result {
        eprintln!("Error: {e}");
        io::stderr().flush().ok();
        process::exit(1);
    }
}
