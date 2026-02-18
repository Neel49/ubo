# ubo-status.sh - Verification logic for ubo
# Sourced by bin/ubo, not run directly

ubo_status() {
  echo -e "${BOLD}ubo status${NC}"
  echo ""

  local all_good=true

  # Chrome installed?
  if [ -d "$CHROME_APP" ]; then
    local chrome_ver
    chrome_ver=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
      "$CHROME_APP/Contents/Info.plist" 2>/dev/null || echo "unknown")
    _status_ok "Chrome installed (v$chrome_ver)"
  else
    _status_fail "Chrome not installed"
    all_good=false
  fi

  # Extension downloaded?
  if [ -d "$UBO_DIR/ublock0.chromium" ] && [ -f "$UBO_DIR/ublock0.chromium/manifest.json" ]; then
    local ver
    ver=$(cat "$UBO_DIR/version" 2>/dev/null || echo "unknown")
    _status_ok "uBlock Origin downloaded ($ver)"
  else
    _status_fail "uBlock Origin not downloaded (run 'ubo install')"
    all_good=false
  fi

  # Launcher app exists?
  if [ -d "$LAUNCHER_APP_PATH" ]; then
    _status_ok "Launcher app installed ($LAUNCHER_APP_PATH)"
  else
    _status_fail "Launcher app not found (run 'ubo install')"
    all_good=false
  fi

  # Chrome running?
  if pgrep -x "Google Chrome" > /dev/null 2>&1; then
    # Check if running with MV2 flags
    if ps aux | grep -v grep | grep "Google Chrome" | grep -q "ExtensionManifestV2Unsupported" 2>/dev/null; then
      _status_ok "Chrome running with MV2 flags"
    else
      _status_warn "Chrome running WITHOUT MV2 flags (relaunch via '${LAUNCHER_APP_NAME}')"
    fi
  else
    _status_info "Chrome not running"
  fi

  echo ""
  if $all_good; then
    success "Everything looks good!"
  else
    echo -e "  Run ${BOLD}ubo install${NC} to fix missing components."
  fi
}

_status_ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
_status_fail() { echo -e "  ${RED}✗${NC} $*"; }
_status_warn() { echo -e "  ${YELLOW}!${NC} $*"; }
_status_info() { echo -e "  ${BLUE}·${NC} $*"; }
