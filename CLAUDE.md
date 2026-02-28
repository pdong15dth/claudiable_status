# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claudiable_status is a **macOS menu bar application** (SwiftUI, macOS 14+) that displays API usage statistics from [Claudible](https://claudible.io). It runs as an accessory app (no dock icon) with a popover dashboard showing balance, usage analytics, spending patterns, and recent activity.

## Build Commands

```bash
# Build (Release)
xcodebuild -project claudiable_status.xcodeproj -scheme claudiable_status -configuration Release -derivedDataPath build

# Build (Debug)
xcodebuild -project claudiable_status.xcodeproj -scheme claudiable_status -configuration Debug -derivedDataPath build
```

Output: `build/Build/Products/{Release|Debug}/claudiable_status.app`

Requires **Xcode 16+** and **macOS 14+** deployment target. No external dependencies — pure Apple frameworks only (SwiftUI, Charts, Observation, Security, SwiftData).

There are no tests in this project.

## Release Process

Automated via GitHub Actions (`.github/workflows/release.yml`):
- Tag push (`v*`) or manual workflow dispatch triggers build, code signing, notarization, DMG creation, and Homebrew cask generation.
- Requires secrets: `MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, `APPLE_API_PRIVATE_KEY_BASE64`.

Manual release helper:
```bash
scripts/prepare_homebrew_release.sh <version> <github_owner> <github_repo>
```

Distribution via Homebrew: `brew tap pdong15dth/tap && brew install --cask claudiable-status`

## Architecture (MVVM)

**App entry & menu bar integration:**
- `claudiable_status/claudiable_statusApp.swift` — SwiftUI app entry point
- `claudiable_status/AppDelegate.swift` — Menu bar status item, popover lifecycle, notification observers. Sets `.accessory` activation policy (no dock icon). Refreshes balance on launch.

**Data layer:**
- `DashboardService.swift` — REST API (`POST https://claudible.io/dashboard/lookup`) and WebSocket (`wss://claudible.io/dashboard/ws`) client. Uses custom ISO8601 date decoder handling both fractional and basic formats.
- `DashboardModels.swift` — Codable models: `LookupResponse`, `UsageStats`, `UsageItem`, `Analytics`, `DashboardWebSocketMessage`
- `APIKeyStore.swift` — Keychain storage for API keys (service: `com.claudiable.status`)

**ViewModel:**
- `DashboardViewModel.swift` — `@Observable` class managing REST fetches, WebSocket connection with auto-reconnect, and live balance updates via Swift Concurrency (`async/await`)

**Views:**
- `claudiable_status/PopoverContentView.swift` — Main UI (~1100 lines). Two display modes: compact (420x320) and full (620x760). Includes charts (SwiftUI Charts), usage tables, spending breakdowns. Dark theme with neon green accent.
- `ToastBanner.swift` — Toast notification overlay

**Configuration:**
- `AppConfig.swift` — Constants (keychain identifiers, WebSocket URL, UserDefaults keys) and `DashboardDisplayMode` enum with persistence
- `DashboardFormatting.swift` — Extensions on `Int`, `Double`, `Date` for currency/number/date formatting

**Inter-component communication:** Uses `NotificationCenter` with custom notification names (`.latestBalanceDidChange`, `.apiKeyDidChange`, `.dashboardDisplayModeDidChange`).

## Key Patterns

- All source files except the app bundle files (`AppDelegate.swift`, `PopoverContentView.swift`, `claudiable_statusApp.swift`, `ContentView.swift`, `Item.swift`) are at the **project root**, not inside the `claudiable_status/` directory.
- Error messages in `DashboardServiceError` are in Vietnamese.
- The app stores the latest balance in `UserDefaults` for offline display and updates it via both REST polling and WebSocket push.
