import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class WallpaperCoordinator: ObservableObject {
    @Published private(set) var playlist: [URL] = []
    @Published private(set) var currentVideoIndex = 0
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var errorMessage: String?
    @Published private(set) var availableDisplays: [DisplayTarget] = []
    @Published private(set) var windowDiagnostics: String = "当前没有附着桌面窗口。"
    @Published private(set) var eventLog: [EventLogEntry] = []
    @Published private(set) var launchAtLoginError: String?
    @Published var playbackStyle: PlaybackStyle = .fill
    @Published var playlistMode: PlaylistMode = .sequential
    @Published var autoApplyOnLaunch = false
    @Published var isMuted = true
    @Published var pauseWhenFullscreenAppActive = false
    @Published var launchAtLoginEnabled = false
    @Published var applyToAllDisplays = false
    @Published var windowLayerStrategy: WindowLayerStrategy = .belowDesktopIcons
    @Published var selectedDisplayID: CGDirectDisplayID?

    private let windowManager = DesktopWindowManager()
    private let playbackController = VideoPlaybackController()
    private let preferences = PrototypePreferencesStore()
    private let launchAtLoginService = LaunchAtLoginService()
    private var diagnosticsTimer: AnyCancellable?
    private var isRecoveringDesktopPlayback = false
    private var lastRecoveryAttemptTime: Date?
    private var multiDisplayCheckCounter = 0
    private let recoveryDebounceInterval: TimeInterval = 0.3

    var canApply: Bool {
        currentVideoURL != nil
    }

    var isPlaying: Bool {
        playbackState == .playing
    }

    var currentVideoURL: URL? {
        guard playlist.indices.contains(currentVideoIndex) else { return nil }
        return playlist[currentVideoIndex]
    }

    var playlistSummaryText: String {
        guard !playlist.isEmpty else { return "播放列表：0 / 0" }
        return "播放列表：\(currentVideoIndex + 1) / \(playlist.count)"
    }

    init() {
        refreshAvailableDisplays()
        installWindowObservation()
        startDiagnosticsRefresh()
        restorePersistedState()
        launchAtLoginEnabled = launchAtLoginService.isEnabled()
        appendLog("协调器已初始化。")

        playbackController.onFailure = { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                self.errorMessage = message
                self.playbackState = .failed
                self.windowManager.destroyDesktopWindow()
                self.refreshWindowDiagnostics()
                self.appendLog("播放失败：\(message)")
            }
        }
        playbackController.onPlaybackEnded = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.advanceToNextVideo()
            }
        }
        playbackController.updateMuted(isMuted)
    }

    func handleImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                setError("未选择任何文件。")
                return
            }
            Task {
                await selectVideos(at: urls)
            }
        case .failure(let error):
            setError("选择文件失败：\(error.localizedDescription)")
        }
    }

    func selectVideos(at urls: [URL]) async {
        errorMessage = nil
        var validatedURLs: [URL] = []

        for url in urls {
            guard await validateFile(url) else { continue }
            validatedURLs.append(url)
        }

        guard !validatedURLs.isEmpty else {
            setError("所选文件都未通过校验。")
            return
        }

        let existingPaths = Set(playlist.map(\.path))
        let appendedURLs = validatedURLs.filter { !existingPaths.contains($0.path) }

        guard !appendedURLs.isEmpty else {
            appendLog("所选视频已存在于播放列表中。")
            return
        }

        let hadExistingPlaylist = !playlist.isEmpty
        let firstAppendedIndex = playlist.count
        playlist.append(contentsOf: appendedURLs)
        currentVideoIndex = hadExistingPlaylist ? firstAppendedIndex : 0
        playbackState = .ready
        preferences.savePlaylistURLs(playlist)
        appendLog("已添加 \(appendedURLs.count) 个视频到播放列表，当前共 \(playlist.count) 个。")

        if currentVideoURL != nil {
            applySelectedVideo()
        }
    }

    func applySelectedVideo(preservePlaybackPosition: Bool = false) {
        guard let url = currentVideoURL else {
            setError("请先至少选择一个本地视频，再应用到桌面。")
            return
        }

        errorMessage = nil
        let resumeTime = preservePlaybackPosition ? playbackController.currentPlaybackTime() : nil

        do {
            let hostViews = try windowManager.prepareDesktopHostViews(
                on: selectedDisplayID,
                layerStrategy: windowLayerStrategy,
                applyToAllDisplays: applyToAllDisplays
            )
            try playbackController.attachAndPlay(
                videoURL: url,
                in: hostViews,
                videoGravity: playbackStyle.videoGravity,
                enableSeamlessLoop: playlist.count == 1,
                startTime: resumeTime
            )
            playbackState = .playing
            refreshWindowDiagnostics()
            appendLog("已将视频应用到桌面：\(url.lastPathComponent)")
        } catch {
            setError(error.localizedDescription)
            windowManager.destroyDesktopWindow()
            refreshWindowDiagnostics()
        }
    }

    func stopPlayback() {
        playbackController.stop()
        windowManager.destroyDesktopWindow()
        playbackState = playlist.isEmpty ? .idle : .ready
        errorMessage = nil
        refreshWindowDiagnostics()
        appendLog("已停止桌面播放。")
    }

    func clearSelection() {
        stopPlayback()
        playlist = []
        currentVideoIndex = 0
        playbackState = .idle
        preferences.clearPlaylistURLs()
        appendLog("已清空播放列表。")
    }

    func removeVideo(at index: Int) {
        removeVideos(at: [index])
    }

    func removeVideos(at indexes: [Int]) {
        let validIndexes = Set(indexes.filter { playlist.indices.contains($0) }).sorted()
        guard !validIndexes.isEmpty else { return }

        let currentVideoWasRemoved = validIndexes.contains(currentVideoIndex)

        for index in validIndexes.reversed() {
            playlist.remove(at: index)
        }

        if playlist.isEmpty {
            stopPlayback()
            currentVideoIndex = 0
            playbackState = .idle
        } else {
            let removedBeforeCurrent = validIndexes.filter { $0 < currentVideoIndex }.count
            if currentVideoWasRemoved {
                let nextIndex = validIndexes.first! - removedBeforeCurrent
                currentVideoIndex = min(max(nextIndex, 0), playlist.count - 1)
            } else {
                currentVideoIndex = max(currentVideoIndex - removedBeforeCurrent, 0)
            }

            if isPlaying {
                applySelectedVideo()
            } else {
                playbackState = .ready
                refreshWindowDiagnostics()
            }
        }

        preferences.savePlaylistURLs(playlist)
        appendLog("已移除 \(validIndexes.count) 个视频。")
    }

    func clearAllVideos() {
        clearSelection()
    }

    func moveVideoUp(at index: Int) {
        guard playlist.indices.contains(index), index > 0 else { return }
        let movedName = playlist[index].lastPathComponent
        playlist.swapAt(index, index - 1)
        adjustCurrentIndexAfterSwap(first: index, second: index - 1)
        preferences.savePlaylistURLs(playlist)
        appendLog("视频已上移：\(movedName)")
    }

    func moveVideoDown(at index: Int) {
        guard playlist.indices.contains(index), index < playlist.count - 1 else { return }
        let movedName = playlist[index].lastPathComponent
        playlist.swapAt(index, index + 1)
        adjustCurrentIndexAfterSwap(first: index, second: index + 1)
        preferences.savePlaylistURLs(playlist)
        appendLog("视频已下移：\(movedName)")
    }

    func updatePlaybackStyle(_ style: PlaybackStyle) {
        playbackStyle = style
        preferences.savePlaybackStyle(style)
        playbackController.updateVideoGravity(style.videoGravity)
        appendLog("播放模式已切换为：\(style.title)。")
    }

    func updateAutoApplyOnLaunch(_ enabled: Bool) {
        autoApplyOnLaunch = enabled
        preferences.saveAutoApplyOnLaunch(enabled)
        appendLog("启动自动应用已\(enabled ? "开启" : "关闭")。")
    }

    func updateMuted(_ muted: Bool) {
        isMuted = muted
        preferences.saveMuted(muted)
        playbackController.updateMuted(muted)
        appendLog("静音已\(muted ? "开启" : "关闭")。")
    }

    func updatePauseWhenFullscreenAppActive(_ enabled: Bool) {
        pauseWhenFullscreenAppActive = false
        preferences.savePauseWhenFullscreenAppActive(false)
        appendLog("已移除前台全屏自动暂停逻辑。")
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            launchAtLoginError = nil
            appendLog("开机自启动已\(launchAtLoginEnabled ? "开启" : "关闭")。")
        } catch {
            launchAtLoginEnabled = launchAtLoginService.isEnabled()
            launchAtLoginError = "更新开机自启动失败：\(error.localizedDescription)"
            appendLog("开机自启动切换失败：\(error.localizedDescription)")
        }
    }

    func updateApplyToAllDisplays(_ enabled: Bool) {
        applyToAllDisplays = enabled
        preferences.saveApplyToAllDisplays(enabled)
        appendLog("应用到所有显示器已\(enabled ? "开启" : "关闭")。")
        refreshWindowDiagnostics()

        if isPlaying {
            applySelectedVideo()
        }
    }

    func updatePlaylistMode(_ mode: PlaylistMode) {
        playlistMode = mode
        preferences.savePlaylistMode(mode)
        appendLog("列表模式已切换为：\(mode.title)。")
    }

    func updateWindowLayerStrategy(_ strategy: WindowLayerStrategy) {
        windowLayerStrategy = strategy
        preferences.saveWindowLayerStrategy(strategy)
        refreshWindowDiagnostics()
        appendLog("窗口层级策略已切换为：\(strategy.title)。")

        if isPlaying {
            applySelectedVideo()
        }
    }

    func refreshAvailableDisplays() {
        availableDisplays = NSScreen.screens.compactMap(DisplayTarget.init(screen:))

        if availableDisplays.isEmpty {
            selectedDisplayID = nil
            preferences.saveSelectedDisplayID(nil)
            appendLog("未检测到任何显示器。")
            return
        }

        if let selectedDisplayID,
           availableDisplays.contains(where: { $0.id == selectedDisplayID }) {
            return
        }

        let persistedID = preferences.loadSelectedDisplayID()
        if let persistedID,
           availableDisplays.contains(where: { $0.id == persistedID }) {
            selectedDisplayID = persistedID
        } else {
            selectedDisplayID = availableDisplays.first?.id
        }
        appendLog("已检测到 \(availableDisplays.count) 个显示器。")
    }

    func updateSelectedDisplay(_ displayID: CGDirectDisplayID) {
        selectedDisplayID = displayID
        preferences.saveSelectedDisplayID(displayID)
        refreshWindowDiagnostics()
        if let display = availableDisplays.first(where: { $0.id == displayID }) {
            appendLog("已切换目标显示器：\(display.name)。")
        }
        if isPlaying {
            applySelectedVideo()
        }
    }

    func refreshDiagnosticsNow() {
        refreshAvailableDisplays()
        refreshWindowDiagnostics()
        recoverDesktopPlaybackIfNeeded(reason: "manual-refresh")
        appendLog("已手动刷新诊断信息。")
    }

    func playNextVideoManually() {
        guard !playlist.isEmpty else { return }
        advanceToNextVideo(userInitiated: true)
    }

    func playPreviousVideoManually() {
        guard !playlist.isEmpty else { return }
        currentVideoIndex = currentVideoIndex == 0 ? playlist.count - 1 : currentVideoIndex - 1
        appendLog("已切换到上一个视频：\(currentVideoURL?.lastPathComponent ?? "未知")")
        if isPlaying {
            applySelectedVideo()
        } else {
            playbackState = .ready
        }
        refreshWindowDiagnostics()
    }

    private func validateFile(_ url: URL) async -> Bool {
        guard url.isFileURL else {
            setError("当前仅支持本地视频文件。")
            return false
        }

        let allowedExtensions = Set(["mp4", "mov"])
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            setError("当前原型仅支持 .mp4 和 .mov 文件。")
            return false
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            setError("所选文件已不存在。")
            return false
        }

        let asset = AVAsset(url: url)
        let videoTracks: [AVAssetTrack]
        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            setError("加载所选视频失败：\(error.localizedDescription)")
            return false
        }

        guard !videoTracks.isEmpty else {
            setError("所选文件中没有可读取的视频轨道。")
            return false
        }

        return true
    }

    private func setError(_ message: String) {
        errorMessage = message
        playbackState = .failed
        refreshWindowDiagnostics()
        appendLog("错误：\(message)")
    }

    private func restorePersistedState() {
        playbackStyle = preferences.loadPlaybackStyle()
        playlistMode = preferences.loadPlaylistMode()
        autoApplyOnLaunch = preferences.loadAutoApplyOnLaunch()
        isMuted = preferences.loadMuted()
        pauseWhenFullscreenAppActive = false
        applyToAllDisplays = preferences.loadApplyToAllDisplays()
        windowLayerStrategy = preferences.loadWindowLayerStrategy()
        playbackController.updateMuted(isMuted)
        if let persistedDisplayID = preferences.loadSelectedDisplayID() {
            selectedDisplayID = persistedDisplayID
        } else {
            selectedDisplayID = availableDisplays.first?.id
        }

        let savedPlaylist = preferences.loadPlaylistURLs()

        guard !savedPlaylist.isEmpty else {
            refreshWindowDiagnostics()
            return
        }

        Task {
            var validURLs: [URL] = []
            for savedURL in savedPlaylist {
                if await validateFile(savedURL) {
                    validURLs.append(savedURL)
                }
            }

            guard !validURLs.isEmpty else {
                preferences.clearPlaylistURLs()
                errorMessage = WallpaperPrototypeError.invalidVideoURL.localizedDescription
                playbackState = .idle
                return
            }

            playlist = validURLs
            currentVideoIndex = 0
            playbackState = .ready
            errorMessage = nil
            refreshWindowDiagnostics()
            appendLog("已恢复播放列表，共 \(validURLs.count) 个视频。")

            if autoApplyOnLaunch {
                applySelectedVideo()
            }
        }
    }

    private func refreshWindowDiagnostics() {
        if let snapshot = windowManager.snapshot() {
            windowDiagnostics = snapshot.summary
        } else if let selectedDisplay = availableDisplays.first(where: { $0.id == selectedDisplayID }) {
            let currentName = currentVideoURL?.lastPathComponent ?? "未选择视频"
            let displayText = applyToAllDisplays ? "所有显示器" : selectedDisplay.summary
            windowDiagnostics = "目标显示器：\(displayText) | \(windowLayerStrategy.title) | \(currentName)"
        } else {
            windowDiagnostics = "当前没有附着桌面窗口。"
        }
    }

    private func installWindowObservation() {
        windowManager.onWindowStateChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.refreshAvailableDisplays()
                self.refreshWindowDiagnostics()
            }
        }
        windowManager.onDiagnosticEvent = { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                self.appendLog(message)
            }
        }
        windowManager.onEnvironmentChange = { [weak self] reason in
            guard let self else { return }
            Task { @MainActor in
                self.recoverDesktopPlaybackIfNeeded(reason: reason)
            }
        }
    }

    private func startDiagnosticsRefresh() {
        diagnosticsTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.isPlaying else { return }
                self.refreshWindowDiagnostics()

                // 在多屏模式下每3秒检查一次窗口状态
                if self.applyToAllDisplays {
                    self.multiDisplayCheckCounter += 1
                    if self.multiDisplayCheckCounter >= 3 {
                        self.multiDisplayCheckCounter = 0
                        self.checkAndFixAllWindowsForMultiDisplay()
                    }
                }
            }
    }

    /// 检查并修复所有显示器的窗口状态（用于多屏模式）
    private func checkAndFixAllWindowsForMultiDisplay() {
        guard applyToAllDisplays else { return }
        guard !isRecoveringDesktopPlayback else { return }

        // 检查每个显示器的窗口状态
        var needReapply = false
        var problemDisplay = ""

        for display in availableDisplays {
            let isVisible = windowManager.isWindowVisibleOnCurrentSpace(for: display.id)
            if !isVisible {
                let detail = windowManager.getDetailedWindowStatus(for: display.id)
                appendLog("显示器 \(display.name) 窗口异常: \(detail)")
                needReapply = true
                problemDisplay = display.name
                break
            }
        }

        if needReapply {
            appendLog("检测到 \(problemDisplay) 窗口异常，重新应用视频")
            isRecoveringDesktopPlayback = true
            defer { isRecoveringDesktopPlayback = false }
            applySelectedVideo(preservePlaybackPosition: true)
        }
    }

    private func recoverDesktopPlaybackIfNeeded(reason: String) {
        guard isPlaying else { return }
        guard !isRecoveringDesktopPlayback else { return }

        let now = Date()

        // 防抖：避免频繁触发恢复
        let debounceInterval: TimeInterval = reason == "active-space" ? 0.2 : recoveryDebounceInterval
        if let lastRecovery = lastRecoveryAttemptTime {
            let elapsed = now.timeIntervalSince(lastRecovery)
            if elapsed < debounceInterval {
                return
            }
        }

        lastRecoveryAttemptTime = now

        // 对于 active-space 变化，直接重新应用视频
        // 因为 AVPlayerLayer 可能在 Space 切换后停止渲染
        if reason == "active-space" {
            appendLog("空间变化，先刷新窗口与图层；必要时保留进度重新挂载")
            windowManager.ensureWindowsVisible()
            windowManager.forceRefreshLayerFrames()
            playbackController.forceUpdateLayerFrames()

            if applyToAllDisplays {
                checkAndFixAllWindowsForMultiDisplay()
            }

            isRecoveringDesktopPlayback = true
            defer { isRecoveringDesktopPlayback = false }

            if !windowManager.hasValidDesktopWindows() {
                applySelectedVideo(preservePlaybackPosition: true)
            }
            return
        }

        checkAndRecoverIfNeeded(afterReason: reason)
    }

    private func checkAndRecoverIfNeeded(afterReason reason: String) {
        guard isPlaying else { return }
        guard !isRecoveringDesktopPlayback else { return }

        let expectedWindowCount = applyToAllDisplays ? max(availableDisplays.count, 1) : 1
        let visibleWindowCount = windowManager.currentDesktopWindowCount()
        let windowStatus = windowManager.getWindowStatusSummary()

        appendLog("检查恢复需求: 预期=\(expectedWindowCount), 可见=\(visibleWindowCount), 状态=[\(windowStatus)]")

        // 先尝试强制刷新窗口和图层
        windowManager.forceRefreshLayerFrames()
        playbackController.forceUpdateLayerFrames()

        // 再次检查窗口状态
        var needReapply = false

        // 检查是否有窗口丢失
        if visibleWindowCount < expectedWindowCount {
            needReapply = true
        }

        // 额外检查：每个目标显示器的窗口是否真的在当前 Space 可见
        if !needReapply {
            if applyToAllDisplays {
                for display in availableDisplays {
                    if !windowManager.isWindowVisibleOnCurrentSpace(for: display.id) {
                        needReapply = true
                        appendLog("显示器 \(display.name) 窗口状态异常")
                        break
                    }
                }
            } else if let selectedID = selectedDisplayID {
                if !windowManager.isWindowVisibleOnCurrentSpace(for: selectedID) {
                    needReapply = true
                    appendLog("目标显示器窗口状态异常")
                }
            }
        }

        if needReapply {
            isRecoveringDesktopPlayback = true
            defer { isRecoveringDesktopPlayback = false }

            appendLog("需要重新应用视频")
            applySelectedVideo(preservePlaybackPosition: true)
        }
    }

    private func appendLog(_ message: String) {
        eventLog.insert(EventLogEntry(timestamp: Date(), message: message), at: 0)
        if eventLog.count > 40 {
            eventLog.removeLast(eventLog.count - 40)
        }
    }

    private func adjustCurrentIndexAfterSwap(first: Int, second: Int) {
        if currentVideoIndex == first {
            currentVideoIndex = second
        } else if currentVideoIndex == second {
            currentVideoIndex = first
        }

        if isPlaying {
            applySelectedVideo()
        } else {
            refreshWindowDiagnostics()
        }
    }

    private func advanceToNextVideo(userInitiated: Bool = false) {
        guard !playlist.isEmpty else { return }

        if playlistMode == .shuffle, playlist.count > 1 {
            var nextIndex = currentVideoIndex
            while nextIndex == currentVideoIndex {
                nextIndex = Int.random(in: 0..<playlist.count)
            }
            currentVideoIndex = nextIndex
        } else {
            currentVideoIndex = (currentVideoIndex + 1) % playlist.count
        }

        let prefix = userInitiated ? "手动切换到" : "自动切换到"
        appendLog("\(prefix)下一个视频：\(currentVideoURL?.lastPathComponent ?? "未知")")

        if isPlaying {
            applySelectedVideo()
        } else {
            playbackState = .ready
            refreshWindowDiagnostics()
        }
    }
}

enum PlaybackState: Equatable {
    case idle
    case ready
    case playing
    case failed

    var description: String {
        switch self {
        case .idle:
            return "空闲：请选择一个本地视频文件。"
        case .ready:
            return "就绪：所选文件已通过初步校验。"
        case .playing:
            return "播放中：视频已附着到桌面窗口。"
        case .failed:
            return "失败：请检查错误信息后重试。"
        }
    }
}

enum PlaybackStyle: String, CaseIterable, Identifiable {
    case fill
    case fit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill:
            return "填充"
        case .fit:
            return "适应"
        }
    }

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:
            return .resizeAspectFill
        case .fit:
            return .resizeAspect
        }
    }
}
