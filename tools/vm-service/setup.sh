#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

exec "$PROJECT_DIR/scripts/setup-tools.sh" --skip-vm-build "$@"
