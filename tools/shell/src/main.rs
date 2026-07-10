mod commands;
mod runner;

fn main() {
    use clap::Parser;
    let cli = commands::Cli::parse();
    runner::enter(cli.command);
}
