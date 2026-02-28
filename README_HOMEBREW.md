# Homebrew Distribution

Distributed via Homebrew Cask. Releases are fully automated.

## End-user install

```bash
brew tap pdong15dth/tap
brew install --cask claudiable-status
```

Update:

```bash
brew update
brew upgrade --cask claudiable-status
```

Uninstall:

```bash
brew uninstall --cask claudiable-status
brew untap pdong15dth/tap
```

## How releases work

When you push a tag like `v1.0.0`, GitHub Actions will automatically:

1. Build the Release app
2. Code sign and notarize (if secrets are configured)
3. Create DMG and ZIP
4. Upload to GitHub Release
5. Update the cask file in `pdong15dth/homebrew-tap` repo

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or trigger manually via Actions → "Release macOS app" → Run workflow.

## One-time setup

### 1. Create the tap repo

Create a **public** repo at `pdong15dth/homebrew-tap`.

The `homebrew-tap/` folder in this project has the initial files. Push it:

```bash
cd homebrew-tap/
git init
git add .
git commit -m "Initial tap setup"
git remote add origin https://github.com/pdong15dth/homebrew-tap.git
git branch -M main
git push -u origin main
```

### 2. Create a Personal Access Token (PAT)

1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Token name: `homebrew-tap-release`
3. Repository access: Only select `homebrew-tap`
4. Permissions: Contents → **Read and write**
5. Generate and copy the token

### 3. Add the secret

1. Go to repo `claudiable_status` → Settings → Secrets and variables → Actions
2. New repository secret: `HOMEBREW_TAP_TOKEN` = the PAT from step 2

### Optional: Code signing and notarization

For signed and notarized builds, add these secrets:

| Secret | Description |
|--------|-------------|
| `MACOS_CERT_P12_BASE64` | Developer ID certificate (base64) |
| `MACOS_CERT_PASSWORD` | Certificate password |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID |
| `APPLE_API_PRIVATE_KEY_BASE64` | API private key (base64) |

Without these, the app will still build and distribute but won't be signed/notarized (users will need to right-click → Open on first launch).

## Manual release (alternative)

If you prefer not to use the automated workflow:

```bash
# Build in Xcode (Release configuration), then:
chmod +x scripts/prepare_homebrew_release.sh
scripts/prepare_homebrew_release.sh 1.0.0
```

This generates `dist/claudiable_status.zip` and `dist/claudiable-status.rb`. Upload the zip to a GitHub Release and copy the `.rb` file to your tap repo manually.
