#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "Building MCP server..."
cd "$PROJECT_DIR/tools/vm-mcp"
npm install
npm run build

mkdir -p "$SYSTEMD_DIR"

echo "Installing systemd services..."
cp "$SCRIPT_DIR/vm.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/vm-mcp.service" "$SYSTEMD_DIR/"

sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm.service"
sed -i "s|%h/proj/angst|$PROJECT_DIR|g" "$SYSTEMD_DIR/vm-mcp.service"

systemctl --user daemon-reload

echo "Enabling services..."
systemctl --user enable vm.service
systemctl --user enable vm-mcp.service

echo ""
echo "Setup complete!"
echo ""
echo "To start the VM and MCP server:"
echo "  systemctl --user start vm"
echo "  systemctl --user start vm-mcp"
echo ""
echo "To enable on login:"
echo "  systemctl --user enable vm"
echo "  systemctl --user enable vm-mcp"
