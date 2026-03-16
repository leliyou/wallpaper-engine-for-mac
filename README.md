# Wallpaper Engine Prototype

Technical prototype for a macOS dynamic wallpaper app on Apple Silicon.

Current minimum supported macOS version: `12.0`.

## Scope

- Single-display desktop-layer playback prototype
- Local `.mp4` / `.mov` file selection
- Looping playback with a minimal SwiftUI control panel
- AppKit-managed desktop window and AVFoundation playback pipeline
- Persist the last selected video and playback mode between launches
- Optional auto-apply of the saved video on app launch
- Display targeting and simple desktop-window diagnostics for validation
- Automatic and manual diagnostics refresh for Window Server state tracking
- In-app event log for playback, display, layer strategy, and workspace state changes
- Multi-video playlist playback with sequential or shuffle rotation
- Menu bar controls, launch-at-login toggle, and basic playlist item management
- Optional automatic pause/resume when a fullscreen app becomes active
- Chinese UI copy for the main window, menu bar actions, status text, and event log

## Run

```bash
swift run
```

## Package App

```bash
zsh scripts/package_app.sh
open dist/"Wallpaper Prototype.app"
```

The packaging script now:

- builds a release binary,
- creates `dist/Wallpaper Prototype.app`,
- applies ad-hoc local signing,
- exports `dist/Wallpaper-Prototype-macOS.zip`.

## Package DMG

```bash
zsh scripts/package_dmg.sh
open dist/Wallpaper-Prototype-macOS.dmg
```

The DMG contains:

- `Wallpaper Prototype.app`
- an `Applications` shortcut for drag-and-drop install

## Release Build

For a real distribution build with Developer ID signing and notarization:

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"
zsh scripts/release_app.sh
```

Optional:

```bash
SKIP_NOTARIZATION=1 zsh scripts/release_app.sh
```

You can create the notary profile ahead of time with:

```bash
xcrun notarytool store-credentials "your-notary-profile" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## Current constraints

- The project is currently delivered as a Swift Package prototype instead of an `.xcodeproj`.
- The critical unknown remains desktop-layer window behavior on the target machine and macOS version.
- The packaged app is only ad-hoc signed locally. Developer ID signing and notarization are still pending for real distribution.

## Repository structure

```text
Sources/     app source code
Resources/   app resources
Packaging/   app bundle metadata and entitlements
scripts/     packaging and release scripts
docs/        project notes and handoff docs
```

## Upload to GitHub

If this directory is not initialized as a Git repository yet:

```bash
git init
git add .
git commit -m "chore: initialize repository"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

If this directory is already a Git repository:

```bash
git add .
git commit -m "chore: add GitHub repo baseline files"
git push
```
