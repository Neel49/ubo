#!/bin/bash
set -euo pipefail

# ubo installer - curl | sh one-liner installer
# Usage: curl -fsSL https://raw.githubusercontent.com/neel49/ubo/main/install.sh | bash

REPO="neel49/ubo"
INSTALL_DIR="/usr/local/share/ubo"
BIN_LINK="/usr/local/bin/ubo"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "==> ${BOLD}$*${NC}"; }
success() { echo -e "${GREEN}==> $*${NC}"; }
error()   { echo -e "${RED}Error: $*${NC}" >&2; }

# Check macOS
if [ "$(uname)" != "Darwin" ]; then
  error "ubo only supports macOS."
  exit 1
fi

# Check dependencies
if ! command -v curl &> /dev/null; then
  error "curl is required."
  exit 1
fi

if ! command -v unzip &> /dev/null; then
  error "unzip is required."
  exit 1
fi

info "Installing ubo..."

# Get latest release tag
LATEST=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null)

if [ -z "$LATEST" ]; then
  error "Could not determine latest version. Check your internet connection."
  exit 1
fi

info "Latest version: $LATEST"

# Download and extract
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

TARBALL="https://github.com/$REPO/archive/refs/tags/$LATEST.tar.gz"
info "Downloading..."
curl -sL "$TARBALL" | tar xz -C "$TMPDIR" --strip-components=1

# Install
info "Installing to $INSTALL_DIR (may require sudo)..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -R "$TMPDIR/bin" "$INSTALL_DIR/"
sudo cp -R "$TMPDIR/lib" "$INSTALL_DIR/"
sudo cp -R "$TMPDIR/resources" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/bin/ubo"

# Symlink
sudo mkdir -p "$(dirname "$BIN_LINK")"
sudo ln -sf "$INSTALL_DIR/bin/ubo" "$BIN_LINK"

echo ""
success "ubo installed successfully!"
echo ""
echo "  Now run:"
echo -e "    ${BOLD}ubo install${NC}"
echo ""
echo "  This will download uBlock Origin and create a Chrome launcher app."
