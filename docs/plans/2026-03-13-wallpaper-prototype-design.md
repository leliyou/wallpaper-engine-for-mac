# macOS Dynamic Wallpaper Prototype Design

## Goal

Build a technical prototype for macOS on MacBook Air M1 that can:

- select a local video file,
- render it on the desktop layer for the main display,
- loop playback reliably,
- keep the initial scope narrow enough to validate desktop-window feasibility.

This is not a product build. It is a feasibility prototype.

## Chosen Direction

The implementation uses a hybrid native stack:

- `SwiftUI` for the lightweight control UI,
- `AppKit` for desktop-window creation and lifecycle management,
- `AVFoundation` for local video playback.

This direction keeps the UI easy to iterate on while preserving native control over window level, screen binding, and playback behavior.

## Alternatives Considered

### 1. Pure AppKit + AVFoundation

Pros:

- maximum control over windowing,
- fewer bridging layers.

Cons:

- slower to iterate on controls,
- more boilerplate for even simple UI.

### 2. SwiftUI + AppKit + AVFoundation

Pros:

- native playback and window control,
- small settings UI is fast to build,
- future expansion to preferences is straightforward.

Cons:

- still requires AppKit integration for desktop behavior.

### 3. Electron/Tauri shell

Pros:

- rapid UI iteration.

Cons:

- weaker control of desktop-layer behavior,
- worse long-running power/performance profile,
- higher risk for a wallpaper-style background app.

## Architecture

The prototype is divided into four components.

### `AppShell`

SwiftUI entry point and minimal control surface. Responsibilities:

- show selected file path,
- open a file picker,
- trigger apply/stop actions,
- render lightweight error state.

### `WallpaperCoordinator`

Stateful orchestration layer. Responsibilities:

- own `selectedVideoURL`, playback state, and error text,
- validate input files,
- create and tear down the desktop playback stack,
- bridge updates between UI and lower-level services.

### `DesktopWindowManager`

AppKit-only window service. Responsibilities:

- create a borderless desktop window for the main screen,
- size and place it to match the display frame,
- host the playback view,
- destroy or hide the window cleanly when playback stops.

### `VideoPlaybackController`

AVFoundation-only playback service. Responsibilities:

- load the local asset,
- create `AVPlayerItem`,
- attach `AVPlayerLayer` to the host view,
- loop playback by seeking back to the start,
- surface playback failures.

## Runtime Flow

1. The app launches into an idle state.
2. The user picks a local `.mp4` or `.mov` file.
3. `WallpaperCoordinator` validates the URL and transitions into a ready state.
4. When the user applies the wallpaper:
   - `DesktopWindowManager` creates a desktop window for the main display,
   - `VideoPlaybackController` binds an `AVPlayerLayer` into that window,
   - playback begins.
5. When playback reaches the end, the player seeks to the beginning and resumes.
6. When the user stops playback or an unrecoverable error occurs:
   - the player stops,
   - the desktop window is removed,
   - the state returns to idle or failed.

## State Model

Initial state machine:

- `idle`
- `ready`
- `playing`
- `failed`

This keeps the prototype small while leaving room for later additions such as pause-on-battery, mute, fill mode, and multi-display support.

## Error Handling

The prototype explicitly handles three classes of failure.

### File errors

- missing file,
- unsupported extension,
- unreadable or undecodable asset.

Result: fail early and do not create the desktop window.

### Desktop window errors

- window appears at the wrong level,
- window blocks normal desktop interaction,
- window does not remain attached to the display frame.

Result: record as the primary technical risk. This is the core feasibility gate for the project.

### Playback errors

- asset loads but does not render,
- loop transition stalls or turns black,
- layer sizing breaks after window updates.

Result: surface an error through the coordinator and tear down cleanly.

## Prototype Acceptance Criteria

The prototype passes only if all of the following are true:

1. The user can pick a local video file and apply it successfully.
2. The video window stays in the intended desktop layer for the main display.
3. Playback loops for several minutes without black frames or a stuck player.

If item 1 passes but item 2 fails, continue investigating desktop-window strategy.

If item 2 passes but item 3 fails, focus on `AVPlayerLayer` lifecycle and loop handling.

## Implementation Notes

- The current environment does not have full Xcode installed, so the initial skeleton is delivered as a Swift Package.
- This should later be migrated to an Xcode app target when full macOS app signing, entitlements, and release packaging are needed.
- The next implementation step is to validate desktop-layer window behavior on the target MacBook Air M1 hardware.
