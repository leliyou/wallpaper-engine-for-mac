import Foundation
import CoreGraphics

struct PrototypePreferencesStore {
    private enum Keys {
        static let playlistBookmarks = "prototype.playlistBookmarks"
        static let playbackStyle = "prototype.playbackStyle"
        static let autoApplyOnLaunch = "prototype.autoApplyOnLaunch"
        static let muted = "prototype.muted"
        static let pauseWhenFullscreenAppActive = "prototype.pauseWhenFullscreenAppActive"
        static let applyToAllDisplays = "prototype.applyToAllDisplays"
        static let selectedDisplayID = "prototype.selectedDisplayID"
        static let windowLayerStrategy = "prototype.windowLayerStrategy"
        static let playlistMode = "prototype.playlistMode"
    }

    private let defaults = UserDefaults.standard

    func savePlaylistURLs(_ urls: [URL]) {
        let bookmarks = urls.compactMap { url -> Data? in
            try? url.bookmarkData()
        }

        defaults.set(bookmarks, forKey: Keys.playlistBookmarks)
    }

    func loadPlaylistURLs() -> [URL] {
        guard let bookmarks = defaults.array(forKey: Keys.playlistBookmarks) as? [Data] else {
            return []
        }

        let urls = bookmarks.compactMap { bookmark -> URL? in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return nil
            }

            return url
        }

        if urls.count != bookmarks.count {
            savePlaylistURLs(urls)
        }

        return urls
    }

    func clearPlaylistURLs() {
        defaults.removeObject(forKey: Keys.playlistBookmarks)
    }

    func savePlaybackStyle(_ style: PlaybackStyle) {
        defaults.set(style.rawValue, forKey: Keys.playbackStyle)
    }

    func loadPlaybackStyle() -> PlaybackStyle {
        guard
            let rawValue = defaults.string(forKey: Keys.playbackStyle),
            let style = PlaybackStyle(rawValue: rawValue)
        else {
            return .fill
        }

        return style
    }

    func saveAutoApplyOnLaunch(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.autoApplyOnLaunch)
    }

    func loadAutoApplyOnLaunch() -> Bool {
        defaults.object(forKey: Keys.autoApplyOnLaunch) as? Bool ?? false
    }

    func saveMuted(_ muted: Bool) {
        defaults.set(muted, forKey: Keys.muted)
    }

    func loadMuted() -> Bool {
        if defaults.object(forKey: Keys.muted) == nil {
            return true
        }

        return defaults.bool(forKey: Keys.muted)
    }

    func savePauseWhenFullscreenAppActive(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.pauseWhenFullscreenAppActive)
    }

    func loadPauseWhenFullscreenAppActive() -> Bool {
        if defaults.object(forKey: Keys.pauseWhenFullscreenAppActive) == nil {
            return true
        }

        return defaults.bool(forKey: Keys.pauseWhenFullscreenAppActive)
    }

    func saveApplyToAllDisplays(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.applyToAllDisplays)
    }

    func loadApplyToAllDisplays() -> Bool {
        defaults.object(forKey: Keys.applyToAllDisplays) as? Bool ?? false
    }

    func saveSelectedDisplayID(_ displayID: CGDirectDisplayID?) {
        guard let displayID else {
            defaults.removeObject(forKey: Keys.selectedDisplayID)
            return
        }

        defaults.set(Int(displayID), forKey: Keys.selectedDisplayID)
    }

    func loadSelectedDisplayID() -> CGDirectDisplayID? {
        guard defaults.object(forKey: Keys.selectedDisplayID) != nil else {
            return nil
        }

        return CGDirectDisplayID(defaults.integer(forKey: Keys.selectedDisplayID))
    }

    func saveWindowLayerStrategy(_ strategy: WindowLayerStrategy) {
        defaults.set(strategy.rawValue, forKey: Keys.windowLayerStrategy)
    }

    func loadWindowLayerStrategy() -> WindowLayerStrategy {
        guard
            let rawValue = defaults.string(forKey: Keys.windowLayerStrategy),
            let strategy = WindowLayerStrategy(rawValue: rawValue)
        else {
            return .belowDesktopIcons
        }

        return strategy
    }

    func savePlaylistMode(_ mode: PlaylistMode) {
        defaults.set(mode.rawValue, forKey: Keys.playlistMode)
    }

    func loadPlaylistMode() -> PlaylistMode {
        guard
            let rawValue = defaults.string(forKey: Keys.playlistMode),
            let mode = PlaylistMode(rawValue: rawValue)
        else {
            return .sequential
        }

        return mode
    }
}
