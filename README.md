# Claudible Status

A macOS menu bar app that displays your [Claudible](https://claudible.io) API usage statistics — balance, spending patterns, usage analytics, and recent activity — all from your menu bar.

## Features

- **Menu bar dashboard** — Quick access to your Claudible balance without opening a browser
- **Live updates** — Real-time balance via WebSocket connection
- **Usage analytics** — Charts and breakdowns of your API spending
- **Compact & full modes** — Toggle between a quick glance (420x320) and detailed view (620x760)
- **Auto-update check** — Notifies you when a new version is available via GitHub Releases
- **In-app upgrade** — Update directly from the settings panel via Homebrew
- **Launch at login** — Optionally start with macOS
- **Dark theme** — Native dark UI with neon green accent

## Requirements

- macOS 14 (Sonoma) or later

## Install

### Homebrew (recommended)

```bash
brew tap pdong15dth/tap
brew install --cask --no-quarantine claudiable-status
```

> The `--no-quarantine` flag is required because the app is distributed outside the Mac App Store.

### Manual

Download the latest `.dmg` from [GitHub Releases](https://github.com/pdong15dth/claudiable_status/releases), open it, and drag **Claudible Status** to your Applications folder.

If macOS blocks the app, run:

```bash
sudo xattr -rd com.apple.quarantine "/Applications/Claudible Status.app"
```

## Update

The app checks for updates automatically and can upgrade itself via Homebrew from the settings panel.

To update manually:

```bash
brew update
brew upgrade --cask claudiable-status
```

## Uninstall

```bash
brew uninstall --cask claudiable-status
brew untap pdong15dth/tap
```

## Usage

1. Launch **Claudible Status** — it appears as a shamrock (☘️) in your menu bar
2. Click the icon to open the dashboard
3. Enter your Claudible API key (stored securely in Keychain)
4. View your balance, usage charts, and spending breakdown

## Source

[github.com/pdong15dth/claudiable_status](https://github.com/pdong15dth/claudiable_status)

## License

MIT
