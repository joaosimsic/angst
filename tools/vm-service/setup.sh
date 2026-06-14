#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SYSTEMD_DIR="$HOME/.config/systemd/user"
VM_CLI="$PROJECT_DIR/tools/vm-cli/target/release/vm"

echo "Building VM CLI..."
cd "$PROJECT_DIR/tools/vm-cli"
cargo build --release

echo "Installing MCP server dependencies..."
cd "$PROJECT_DIR/tools/vm-mcp"
bun install

mkdir -p "$SYSTEMD_DIR"

echo "Installing systemd services..."
cp "$SCRIPT_DIR/vm.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/vm-mcp.service" "$SYSTEMD_DIR/"

sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm.service"
sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm-mcp.service"

systemctl --user daemon-reload

echo ""
echo "Setup complete! Services are installed but NOT enabled at startup."
echo ""
echo "Use the VM CLI to manage the VM:"
echo "  $VM_CLI start"
echo "  $VM_CLI stop"
echo "  $VM_CLI status"
echo "  $VM_CLI ssh"
echo ""
echo "Or use systemctl directly:"
echo "  systemctl --user start vm"
echo "  systemctl --user start vm-mcp"
