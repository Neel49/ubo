# ubo

One-command uBlock Origin installer for Google Chrome on macOS.

Installs [uBlock Origin](https://github.com/gorhill/uBlock) (the full MV2 version) and creates a Chrome launcher that keeps MV2 extensions alive — all with a single command.

## Install

**Option A: Homebrew**

```bash
brew tap neel49/ubo
brew install ubo
ubo install
```

**Option B: curl**

```bash
curl -fsSL https://raw.githubusercontent.com/neel49/ubo/main/install.sh | bash
ubo install
```

**Option C: From source**

```bash
git clone https://github.com/neel49/ubo.git
cd ubo
make install
ubo install
```

## What it does

1. Downloads the latest uBlock Origin from [GitHub releases](https://github.com/gorhill/uBlock/releases)
2. Creates a **Chrome uBO** app in `/Applications` that launches Chrome with MV2 support flags
3. uBlock Origin loads automatically when you open Chrome through the launcher

## Usage

```bash
ubo install     # Set up everything
ubo status      # Check installation status
ubo update      # Update uBlock Origin to latest release
ubo launch      # Open Chrome with uBlock Origin
ubo uninstall   # Remove everything
```

## How it works

Chrome is deprecating Manifest V2 extensions, which uBlock Origin relies on. This tool:

- Downloads the uBlock Origin extension files to `~/.ubo/`
- Creates a macOS app that launches Chrome with `--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled` and `--load-extension` flags
- The launcher app uses Chrome's own icon and can be pinned to your Dock

## After installing

1. **Quit Chrome** if it's running
2. Open **Chrome uBO** from `/Applications` or Spotlight
3. Chrome will show a "developer mode extensions" dialog — click **Cancel** to dismiss
4. uBlock Origin is loaded and ready to go
5. Pin **Chrome uBO** to your Dock so you always launch Chrome with uBlock Origin

## Important notes

- Always open Chrome through the **Chrome uBO** app (not the regular Chrome). Regular Chrome won't have uBlock Origin or MV2 support.
- If Chrome is already running, the launcher will offer to quit and relaunch it with the correct flags.
- The extension doesn't auto-update. Run `ubo update` periodically to get the latest version.
- Google could remove the MV2 flag support in future Chrome versions.

## Uninstall

```bash
ubo uninstall           # Remove extension and launcher app
brew uninstall ubo      # Remove the ubo command (Homebrew)
# or
sudo rm /usr/local/bin/ubo  # Remove the ubo command (curl install)
```

## License

MIT
