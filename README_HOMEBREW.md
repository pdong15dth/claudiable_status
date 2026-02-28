# Homebrew install setup

This project is prepared for distribution via Homebrew Cask.

## Automatic release (recommended)

This repo includes workflow:

- `.github/workflows/release.yml`

When you push a tag like `v1.0.0`, GitHub Actions will:

1. Build Release app from `claudiable_status.xcodeproj`
2. Create `claudiable_status.zip`
3. Generate `sha256` and cask file
4. Upload assets to GitHub Release

Uploaded release assets:

- `claudiable_status.zip`
- `claudiable_status.zip.sha256`
- `claudiable-status-cask.rb`

Trigger release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 1) Build app bundle

In Xcode, build the app in Release so this path exists:

`claudiable_status/Products/claudiable_status.app`

## 2) Prepare release assets + cask file

Run:

```bash
chmod +x scripts/prepare_homebrew_release.sh
scripts/prepare_homebrew_release.sh <version> [github_owner] [github_repo]
```

Example:

```bash
scripts/prepare_homebrew_release.sh 1.0.0
# or explicit:
scripts/prepare_homebrew_release.sh 1.0.0 pdong15dth claudiable_status
```

It generates:

- `dist/claudiable_status.zip`
- `dist/claudiable-status.rb`

## 3) Publish GitHub Release

Create release tag `v<version>` and upload `dist/claudiable_status.zip`.

Example:

- tag: `v1.0.0`
- asset: `claudiable_status.zip`
- release URL: `https://github.com/pdong15dth/claudiable_status/releases/tag/v1.0.0`

## 4) Publish Homebrew tap

Create a tap repo named:

`homebrew-tap`

In that repo:

1. Create folder `Casks/`
2. Copy `claudiable-status-cask.rb` from GitHub Release assets to `Casks/claudiable-status.rb`
3. Commit and push

## 5) End-user install command

```bash
brew tap <github_owner>/tap
brew install --cask claudiable-status
```

For your repo:

```bash
brew tap pdong15dth/tap
brew install --cask claudiable-status
```

Update command:

```bash
brew update
brew upgrade --cask claudiable-status
```
