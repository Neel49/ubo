# ubo-uninstall.sh - Cleanup logic for ubo
# Sourced by bin/ubo, not run directly

ubo_uninstall() {
  info "Uninstalling ubo..."
  echo ""

  local removed=0

  # 1. Remove launcher app
  if [ -d "$LAUNCHER_APP_PATH" ]; then
    rm -rf "$LAUNCHER_APP_PATH"
    echo "  Removed $LAUNCHER_APP_PATH"
    removed=1
  fi

  # 2. Remove extension data
  if [ -d "$UBO_DIR" ]; then
    rm -rf "$UBO_DIR"
    echo "  Removed $UBO_DIR"
    removed=1
  fi

  if [ "$removed" -eq 0 ]; then
    echo "  Nothing to uninstall."
    return 0
  fi

  echo ""
  success "ubo has been uninstalled."
  echo ""
  echo "  Note: If uBlock Origin was loaded in a Chrome session, it will"
  echo "  disappear next time you restart Chrome normally."
  echo ""
  echo "  To remove the 'ubo' command itself:"
  echo "    brew uninstall ubo          # if installed via Homebrew"
  echo "    sudo rm /usr/local/bin/ubo  # if installed via curl|sh"
}
