#!/usr/bin/env bash
# Super Ralphy Installer
# https://github.com/sashabogojevic/super-ralphy

set -e

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Super Ralphy..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy script
cp "$SCRIPT_DIR/super-ralphy.sh" "$INSTALL_DIR/super-ralphy"
chmod +x "$INSTALL_DIR/super-ralphy"

# Check if in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo ""
  echo "⚠️  $INSTALL_DIR is not in your PATH"
  echo ""
  echo "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

echo "✅ Super Ralphy installed to $INSTALL_DIR/super-ralphy"
echo ""
echo "Usage:"
echo "  super-ralphy \"add login button\""
echo "  super-ralphy --prd PRD.md"
echo "  super-ralphy --help"
