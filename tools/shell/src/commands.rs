use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "shell", version)]
pub struct CLI {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    Dev,
    Safe,
}
