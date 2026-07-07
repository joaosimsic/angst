mod commands;
mod runner;

fn main() {
    use clap::Parser;
    let cli = commands::CLI::parse();
    runner::enter(cli.command);
}
