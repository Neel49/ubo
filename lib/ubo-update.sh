# ubo-update.sh - Update uBlock Origin to latest release
# Sourced by bin/ubo, not run directly

ubo_update() {
  # Check if installed
  if [ ! -d "$UBO_DIR/ublock0.chromium" ]; then
    error "uBlock Origin is not installed. Run 'ubo install' first."
    exit 1
  fi

  local current_ver
  current_ver=$(cat "$UBO_DIR/version" 2>/dev/null || echo "unknown")

  # Check internet
  if ! curl -s --head --max-time 5 https://api.github.com > /dev/null 2>&1; then
    error "Cannot reach GitHub. Check your internet connection."
    exit 1
  fi

  info "Checking for updates..."
  info "Current version: $current_ver"

  # Get latest version from GitHub
  local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
  local release_json
  release_json=$(curl -sL "$api_url")

  local latest_ver
  latest_ver=$(echo "$release_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null)

  if [ -z "$latest_ver" ]; then
    error "Could not check latest version. GitHub API may be rate-limited."
    exit 1
  fi

  info "Latest version:  $latest_ver"

  if [ "$current_ver" = "$latest_ver" ]; then
    success "Already up to date!"
    return 0
  fi

  echo ""
  info "Updating $current_ver → $latest_ver..."

  # Extract download URL
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
    error "Could not find download URL for latest release."
    exit 1
  fi

  # Download
  local zip_path="$UBO_DIR/ublock0.chromium.zip"
  if ! curl -sL --progress-bar "$zip_url" -o "$zip_path"; then
    error "Download failed."
    exit 1
  fi

  # Replace extension (extract to temp dir, normalize folder name)
  local extract_tmp="$UBO_DIR/_extract_tmp"
  rm -rf "$extract_tmp" "$UBO_DIR/ublock0.chromium"
  mkdir -p "$extract_tmp"
  unzip -qo "$zip_path" -d "$extract_tmp/"

  local extracted
  extracted=$(find "$extract_tmp" -maxdepth 1 -type d -name "uBlock*" -o -type d -name "ublock*" | grep -i chromium | head -1)
  if [ -n "$extracted" ]; then
    mv "$extracted" "$UBO_DIR/ublock0.chromium"
  elif [ -f "$extract_tmp/manifest.json" ]; then
    mv "$extract_tmp" "$UBO_DIR/ublock0.chromium"
  fi
  rm -rf "$extract_tmp"

  echo "$latest_ver" > "$UBO_DIR/version"
  rm -f "$zip_path"

  echo ""
  success "Updated to uBlock Origin $latest_ver"

  if pgrep -x "Google Chrome" > /dev/null 2>&1; then
    echo ""
    warn "Chrome is running. Restart Chrome via '${LAUNCHER_APP_NAME}' to load the update."
  fi
}
