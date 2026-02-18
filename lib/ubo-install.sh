# ubo-install.sh - Installation logic for ubo
# Sourced by bin/ubo, not run directly

ubo_install() {
  info "ubo installer v$UBO_VERSION"
  echo ""

  # 1. Check macOS
  if [ "$(uname)" != "Darwin" ]; then
    error "ubo only supports macOS."
    exit 1
  fi

  # 2. Check Chrome is installed
  if [ ! -d "$CHROME_APP" ]; then
    error "Google Chrome not found at $CHROME_APP"
    echo "  Install Chrome from https://google.com/chrome and try again."
    exit 1
  fi

  local chrome_ver
  chrome_ver=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
    "$CHROME_APP/Contents/Info.plist" 2>/dev/null || echo "unknown")
  info "Found Chrome $chrome_ver"

  # 3. Check internet connectivity
  if ! curl -s --head --max-time 5 https://api.github.com > /dev/null 2>&1; then
    error "Cannot reach GitHub. Check your internet connection."
    exit 1
  fi

  # 4. Warn if Chrome is running
  if pgrep -x "Google Chrome" > /dev/null 2>&1; then
    warn "Chrome is currently running."
    echo "  You'll need to quit Chrome and relaunch via 'Chrome uBO' for changes to take effect."
    echo ""
  fi

  # 5. Check for existing installation
  if [ -d "$UBO_DIR/ublock0.chromium" ] && [ -f "$UBO_DIR/version" ]; then
    local current_ver
    current_ver=$(cat "$UBO_DIR/version" 2>/dev/null || echo "unknown")
    warn "uBlock Origin $current_ver is already installed."
    read -rp "  Reinstall? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "  Skipping download. Checking launcher app..."
      _ensure_launcher
      return 0
    fi
  fi

  # 6. Download extension
  _download_extension

  # 7. Create launcher app
  _ensure_launcher

  # 8. Print success
  echo ""
  success "Installation complete!"
  echo ""
  echo "  uBlock Origin: $(cat "$UBO_DIR/version" 2>/dev/null)"
  echo "  Extension:     $UBO_DIR/ublock0.chromium/"
  echo "  Launcher:      $LAUNCHER_APP_PATH"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo "  1. Quit Chrome completely if it's running"
  echo "  2. Open '${LAUNCHER_APP_NAME}' from /Applications or Spotlight"
  echo "  3. Pin '${LAUNCHER_APP_NAME}' to your Dock for easy access"
  echo ""
  echo -e "  ${YELLOW}Note:${NC} Chrome will show a 'developer mode extensions' dialog on launch."
  echo "  Just click 'Cancel' to dismiss it. This is expected."
}

_download_extension() {
  info "Fetching latest uBlock Origin release..."

  local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
  local release_json
  release_json=$(curl -sL "$api_url")

  # Extract version tag
  local version
  version=$(echo "$release_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null)
  if [ -z "$version" ]; then
    error "Could not determine latest uBlock Origin version."
    error "GitHub API may be rate-limited. Try again in a few minutes."
    exit 1
  fi

  # Extract download URL for ublock0.chromium.zip
  local zip_url
  zip_url=$(echo "$release_json" | python3 -c "
import sys, json
assets = json.load(sys.stdin)['assets']
for a in assets:
    if 'chromium' in a['name'] and a['name'].endswith('.zip'):
        print(a['browser_download_url'])
        break
" 2>/dev/null)

  if [ -z "$zip_url" ]; then
    error "Could not find ublock0.chromium.zip in the latest release."
    exit 1
  fi

  info "Downloading uBlock Origin $version..."
  mkdir -p "$UBO_DIR"

  local zip_path="$UBO_DIR/ublock0.chromium.zip"
  if ! curl -sL --progress-bar "$zip_url" -o "$zip_path"; then
    error "Download failed."
    exit 1
  fi

  # Unzip into a temp dir, then normalize the folder name
  info "Extracting..."
  local extract_tmp="$UBO_DIR/_extract_tmp"
  rm -rf "$extract_tmp" "$UBO_DIR/ublock0.chromium"
  mkdir -p "$extract_tmp"
  unzip -qo "$zip_path" -d "$extract_tmp/"

  # Find the extracted extension directory (case-insensitive match)
  local extracted
  extracted=$(find "$extract_tmp" -maxdepth 1 -type d -name "uBlock*" -o -type d -name "ublock*" | grep -i chromium | head -1)
  if [ -n "$extracted" ]; then
    mv "$extracted" "$UBO_DIR/ublock0.chromium"
  else
    # Fallback: maybe it extracted directly without a subdirectory
    if [ -f "$extract_tmp/manifest.json" ]; then
      mv "$extract_tmp" "$UBO_DIR/ublock0.chromium"
    else
      error "Extraction failed: could not find extension directory."
      rm -rf "$extract_tmp"
      exit 1
    fi
  fi
  rm -rf "$extract_tmp"

  # Verify manifest.json exists
  if [ ! -f "$UBO_DIR/ublock0.chromium/manifest.json" ]; then
    error "Invalid extension: manifest.json not found."
    exit 1
  fi

  # Save version
  echo "$version" > "$UBO_DIR/version"

  # Clean up zip
  rm -f "$zip_path"

  success "Downloaded uBlock Origin $version"
}

_ensure_launcher() {
  if [ -d "$LAUNCHER_APP_PATH" ]; then
    rm -rf "$LAUNCHER_APP_PATH"
  fi
  _create_launcher
}

_create_launcher() {
  info "Creating '${LAUNCHER_APP_NAME}' app..."

  local script_path="$UBO_DIR/chrome-ubo.applescript"

  # Write the AppleScript
  if [ -f "$RESOURCES_DIR/chrome-ubo.applescript" ]; then
    cp "$RESOURCES_DIR/chrome-ubo.applescript" "$script_path"
  else
    # Inline fallback if resources dir isn't available
    cat > "$script_path" << 'APPLESCRIPT'
on run
	set extensionPath to (POSIX path of (path to home folder)) & ".ubo/ublock0.chromium"
	set mv2Flags to "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
	set loadFlag to ""
	try
		do shell script "test -d " & quoted form of extensionPath
		set loadFlag to " --load-extension=" & quoted form of extensionPath
	end try
	set chromeRunning to false
	try
		tell application "System Events"
			set chromeRunning to (exists (processes where name is "Google Chrome"))
		end tell
	end try
	if chromeRunning then
		tell application "Google Chrome" to activate
	else
		do shell script "open -a '/Applications/Google Chrome.app' --args " & mv2Flags & loadFlag
	end if
end run
APPLESCRIPT
  fi

  # Compile to .app
  if ! osacompile -o "$LAUNCHER_APP_PATH" "$script_path" 2>/dev/null; then
    error "Failed to create launcher app."
    error "Try running: osacompile -o '$LAUNCHER_APP_PATH' '$script_path'"
    exit 1
  fi

  # Copy Chrome's icon to the launcher app
  local chrome_icon="$CHROME_APP/Contents/Resources/app.icns"
  local launcher_icon="$LAUNCHER_APP_PATH/Contents/Resources/applet.icns"
  if [ -f "$chrome_icon" ]; then
    cp "$chrome_icon" "$launcher_icon"
    touch "$LAUNCHER_APP_PATH"  # Refresh icon cache
  fi

  success "Created launcher app at $LAUNCHER_APP_PATH"
}
