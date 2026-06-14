mod commands;
mod config;
mod ssh;
mod systemd;

use clap::{Parser, Subcommand};
use std::io::Write;
use std::process;

#[derive(Parser)]
#[command(name = "vm", about = "VM management CLI", version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    
    Start,
    
    Stop,
    
    Restart,
    
    Status,
    
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
    
    Ssh {
        #[arg(last = true)]
        args: Vec<String>,
    },
    
    Exec {
        #[arg(required = true, last = true)]
        command: Vec<String>,
    },
    
    CopyTo {
        src: String,
        dest: Option<String>,
    },
    
    CopyFrom {
        src: String,
        dest: Option<String>,
    },
    
    Mcp {
        #[command(subcommand)]
        action: McpCommands,
    },
}

#[derive(Subcommand)]
enum McpCommands {
    
    Start,
    
    Stop,
    
    Restart,
    
    Status,
    
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Start => commands::vm::start(),
        Commands::Stop => commands::vm::stop(),
        Commands::Restart => commands::vm::restart(),
        Commands::Status => commands::vm::status(),
        Commands::Logs { lines } => commands::vm::logs(lines),
        Commands::Ssh { args } => commands::remote::ssh(&args),
        Commands::Exec { command } => commands::remote::exec(&command),
        Commands::CopyTo { src, dest } => commands::remote::copy_to(&src, dest.as_deref()),
        Commands::CopyFrom { src, dest } => commands::remote::copy_from(&src, dest.as_deref()),
        Commands::Mcp { action } => match action {
            McpCommands::Start => commands::mcp::start(),
            McpCommands::Stop => commands::mcp::stop(),
            McpCommands::Restart => commands::mcp::restart(),
            McpCommands::Status => commands::mcp::status(),
            McpCommands::Logs { lines } => commands::mcp::logs(lines),
        },
    };

    if let Err(e) = result {
        eprintln!("Error: {e}");
        std::io::stderr().flush().ok();
        process::exit(1);
    }
}
