use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "vm", version)]
pub struct CLI {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
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
        dest: String,
    },
    CopyFrom {
        src: String,
        dest: String,
    },
    Mcp {
        #[command(subcommand)]
        action: McpCommands,
    },
}

#[derive(Subcommand)]
pub enum McpCommands {
    Start,
    Stop,
    Restart,
    Status,
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
    RunServer {
        #[arg(short, long, default_value = "8765")]
        port: u16,
    },
}
