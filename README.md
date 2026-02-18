# ubo

One-command uBlock Origin installer for Google Chrome on **macOS** and **Windows**.

Installs [uBlock Origin](https://github.com/gorhill/uBlock) (the full MV2 version) and creates a Chrome launcher that keeps MV2 extensions alive — all with a single command.

## Install

### macOS (Homebrew)

**Step 1** — Install the `ubo` command:
```bash
brew tap neel49/ubo && brew install ubo
```

**Step 2** — Download uBlock Origin and create the launcher:
```bash
ubo install
```

### macOS (curl)

**Step 1** — Install the `ubo` command:
```bash
curl -fsSL https://raw.githubusercontent.com/neel49/ubo/main/install.sh | bash
```

**Step 2** — Download uBlock Origin and create the launcher:
```bash
ubo install
```

### Windows

**Step 1** — Install the `ubo` command:
```powershell
irm https://raw.githubusercontent.com/neel49/ubo/main/windows/install.ps1 | iex
```

**Step 2** — Download uBlock Origin and create the shortcuts:
```powershell
ubo install
```

## What it does

1. Downloads the latest uBlock Origin from [GitHub releases](https://github.com/gorhill/uBlock/releases)
2. Creates a **Chrome uBO** launcher (macOS app / Windows shortcut) that opens Chrome with MV2 support flags
3. uBlock Origin loads automatically when you open Chrome through the launcher

## Usage

```
ubo install     # Set up everything
ubo status      # Check installation status
ubo update      # Update uBlock Origin to latest release
ubo launch      # Open Chrome with uBlock Origin
ubo uninstall   # Remove everything
```

## How it works

Chrome is deprecating Manifest V2 extensions, which uBlock Origin relies on. This tool:

- Downloads the uBlock Origin extension files locally
- Creates a launcher that starts Chrome with `--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled` and `--load-extension` flags
- **macOS**: Creates a "Chrome uBO" app in `/Applications` (pin to Dock)
- **Windows**: Creates a "Chrome uBO" shortcut on Desktop and Start Menu (pin to taskbar)

## After installing

1. **Close Chrome** completely if it's running
2. Open **Chrome uBO** from your Dock (macOS) or Desktop (Windows)
3. Chrome will show a "developer mode extensions" dialog — click **Cancel** to dismiss
4. uBlock Origin is loaded and ready to go
5. Pin **Chrome uBO** to your Dock/taskbar for easy access

## Important notes

- Always open Chrome through **Chrome uBO** (not regular Chrome). Regular Chrome won't have uBlock Origin or MV2 support.
- If Chrome is already running with the right flags, the launcher just brings it to the front.
- If Chrome is running without flags, the launcher will offer to restart it.
- The extension doesn't auto-update. Run `ubo update` periodically to get the latest version.
- Google could remove the MV2 flag support in future Chrome versions.

## Uninstall

**macOS:**
```bash
ubo uninstall
brew uninstall ubo
```

**Windows:**
```powershell
ubo uninstall
```


## Credits

This entire process is just a wrapper for the process defined here (just me trying to make it easier to do): https://www.reddit.com/r/uBlockOrigin/comments/1mtowwf/end_of_support_for_ubo_on_chrome_chromium/

