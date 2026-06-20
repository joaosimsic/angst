use vm_cli::run_cli;

#[tokio::main]
async fn main() {
    if let Err(e) = run_cli().await {
        println!("Error: {}", e);
        std::process::exit(1);
    }
}
