pub mod mcp;
pub mod vm;

use crate::commands::{CLI, Commands};
use clap::Parser;
use vm_core::SshEngine;

pub async fn run_cli() -> Result<(), String> {
    let cli = CLI::parse();
    let ssh = SshEngine::new();

    match cli.command {
        Commands::Start { headless } => vm::start(&ssh, headless).await,
        Commands::Stop => vm_core::VmProcessController::stop("vm"),
        Commands::Restart { headless } => {
            let _ = vm_core::VmProcessController::stop("vm");
            vm::start(&ssh, headless).await
        }
        Commands::Status => vm::status(&ssh),
        Commands::Logs { lines } => vm_core::VmProcessController::stream_logs("vm", lines),
        Commands::Ssh { auto_start, tty, args } => vm::ssh(&ssh, auto_start, tty, args).await,
        Commands::Exec { command } => vm::exec(&ssh, command),
        Commands::Health => vm::health(&ssh),
        Commands::CopyTo { src, dest } => ssh.copy_to(&src, &dest),
        Commands::CopyFrom { src, dest } => ssh.copy_from(&src, &dest),
        Commands::Mcp { action } => mcp::handle(action).await,
    }
}
