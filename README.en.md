# Wallpaper Engine Prototype

[中文](./README.md) | [English](./README.en.md)

A macOS dynamic wallpaper prototype for Apple Silicon.

## 1. Requirements

- Chip: Apple Silicon (M1 / M2 / M3 / M4)
- OS: macOS 13+ (project minimum target is `macOS 12.0`)
- Tools: Xcode + Command Line Tools

## 2. Xcode Versions for macOS 13 (Ventura)

As of `2026-03-16`, recommended versions are `Xcode 14.3.1` or `Xcode 15.2`.

- `Xcode 14.3.1`: supports Ventura 13.x
- `Xcode 15.0.x / 15.1 / 15.2`: requires macOS 13.5+
- `Xcode 15.3+`: requires macOS 14+
- `Xcode 16+`: requires macOS 14.5+

Official links:

- App Store: https://apps.apple.com/us/app/xcode/id497799835?mt=12
- Apple Developer downloads: https://developer.apple.com/download/all/?q=xcode
- Compatibility table: https://developer.apple.com/cn/xcode/system-requirements/

Initialize after install:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version
swift --version
```

## 3. Run Locally

```bash
swift run
```

## 4. Packaging

Build app bundle:

```bash
zsh scripts/package_app.sh
```

Build DMG:

```bash
zsh scripts/package_dmg.sh
```

Release build (Developer ID + notarization):

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"
zsh scripts/release_app.sh
```

## 5. Upload Installers to GitHub Tag Release

Artifacts to upload:

- `dist/Wallpaper-Prototype-macOS.dmg`
- `dist/Wallpaper-Prototype-macOS.zip`

Web flow:

1. Open repository -> `Releases` -> `Draft a new release`.
2. Set tag (for example `v0.1.0`) and title.
3. Upload files in `Attach binaries`.
4. Write release notes and publish.

CLI flow (`gh`):

```bash
gh auth login
gh release create v0.1.0 \
  dist/Wallpaper-Prototype-macOS.dmg \
  dist/Wallpaper-Prototype-macOS.zip \
  --title "v0.1.0" \
  --notes "First public preview release"
```

If release exists:

```bash
gh release upload v0.1.0 dist/Wallpaper-Prototype-macOS.dmg dist/Wallpaper-Prototype-macOS.zip --clobber
```

## 6. README Language Switching on GitHub

GitHub shows only root `README.md` on the homepage. There is no true auto language switch.
Use top links to switch manually:

- Chinese: `README.md`
- English: `README.en.md`
