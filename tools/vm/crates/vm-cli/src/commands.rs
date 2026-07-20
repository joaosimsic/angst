use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "vm", version)]
pub struct CLI {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    Start {
        #[arg(short = 'l', long = "headless")]
        headless: bool,
    },
    Stop,
    Restart {
        #[arg(short = 'l', long = "headless")]
        headless: bool,
    },
    Status,
    Logs {
        #[arg(short, long, default_value = "50")]
        lines: u32,
    },
    Ssh {
        #[arg(short = 'a', long = "auto-start", help = "Start the VM if not running")]
        auto_start: bool,
        #[arg(short = 't', long = "tty", help = "Force pseudo-terminal allocation")]
        tty: bool,
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
    Health,
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

#[cfg(test)]
mod tests {
    use super::{CLI, Commands, McpCommands};
    use clap::Parser;

    #[test]
    fn parses_headless_restart() {
        let cli = CLI::parse_from(["vm", "restart", "--headless"]);

        match cli.command {
            Commands::Restart { headless } => assert!(headless),
            _ => panic!("expected restart command"),
        }
    }

    #[test]
    fn parses_exec_command_after_separator() {
        let cli = CLI::parse_from(["vm", "exec", "--", "echo", "hello"]);

        match cli.command {
            Commands::Exec { command } => assert_eq!(command, ["echo", "hello"]),
            _ => panic!("expected exec command"),
        }
    }

    #[test]
    fn parses_mcp_logs_default_lines() {
        let cli = CLI::parse_from(["vm", "mcp", "logs"]);

        match cli.command {
            Commands::Mcp {
                action: McpCommands::Logs { lines },
            } => assert_eq!(lines, 50),
            _ => panic!("expected mcp logs command"),
        }
    }

    #[test]
    fn parses_mcp_run_server_default_port() {
        let cli = CLI::parse_from(["vm", "mcp", "run-server"]);

        match cli.command {
            Commands::Mcp {
                action: McpCommands::RunServer { port },
            } => assert_eq!(port, 8765),
            _ => panic!("expected mcp run-server command"),
        }
    }
}
