import AppKit
import AVFoundation
import QuartzCore

@MainActor
final class VideoPlaybackController {
    var onFailure: ((String) -> Void)?
    var onPlaybackEnded: (() -> Void)?

    private var player: AVPlayer?
    private var playerLayers: [AVPlayerLayer] = []
    private var playbackEndObserver: NSObjectProtocol?
    private var readyForDisplayObservers: [NSKeyValueObservation] = []
    private var pendingTransitionWorkItem: DispatchWorkItem?
    private var activeTransitionID = UUID()
    private var isPaused = false
    private var isMuted = true

    deinit {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    func attachAndPlay(
        videoURL: URL,
        in hostViews: [NSView],
        videoGravity: AVLayerVideoGravity,
        enableSeamlessLoop: Bool = false,
        startTime: CMTime? = nil
    ) throws {
        let previousPlayer = player
        let previousLayers = playerLayers

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        readyForDisplayObservers.forEach { $0.invalidate() }
        readyForDisplayObservers.removeAll()
        pendingTransitionWorkItem?.cancel()
        pendingTransitionWorkItem = nil

        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = enableSeamlessLoop ? .none : .pause

        var layers: [AVPlayerLayer] = []
        for hostView in hostViews {
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = videoGravity
            layer.frame = hostView.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.opacity = previousLayers.isEmpty ? 1 : 0
            hostView.layer?.addSublayer(layer)
            layers.append(layer)
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if enableSeamlessLoop {
                    self.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.player?.play()
                } else {
                    self.onPlaybackEnded?()
                }
            }
        }

        self.player = player
        self.playerLayers = layers
        self.isPaused = false
        self.player?.isMuted = isMuted

        if let startTime, startTime.isValid, !startTime.isIndefinite, startTime.seconds > 0 {
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        player.play()

        if !previousLayers.isEmpty {
            let transitionID = UUID()
            activeTransitionID = transitionID
            let performTransition = { [weak self] in
                guard let self else { return }
                guard self.activeTransitionID == transitionID else { return }

                CATransaction.begin()
                CATransaction.setAnimationDuration(0.22)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                CATransaction.setCompletionBlock {
                    previousPlayer?.pause()
                    previousLayers.forEach { $0.removeFromSuperlayer() }
                    self.readyForDisplayObservers.forEach { $0.invalidate() }
                    self.readyForDisplayObservers.removeAll()
                    self.pendingTransitionWorkItem = nil
                }

                layers.forEach { $0.opacity = 1 }
                previousLayers.forEach { $0.opacity = 0 }
                CATransaction.commit()
            }

            if let firstLayer = layers.first {
                let observer = firstLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { _, _ in
                    if firstLayer.isReadyForDisplay {
                        performTransition()
                    }
                }
                readyForDisplayObservers.append(observer)
            }

            let fallbackWorkItem = DispatchWorkItem(block: performTransition)
            pendingTransitionWorkItem = fallbackWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: fallbackWorkItem)
        }

        if player.status == .failed {
            onFailure?("播放失败：\(player.error?.localizedDescription ?? "未知 AVPlayer 错误")")
        }
    }

    func updateVideoGravity(_ videoGravity: AVLayerVideoGravity) {
        playerLayers.forEach { $0.videoGravity = videoGravity }
    }

    func updateMuted(_ muted: Bool) {
        isMuted = muted
        player?.isMuted = muted
    }

    func pause() {
        player?.pause()
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        player?.play()
        isPaused = false
    }

    func stop() {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        readyForDisplayObservers.forEach { $0.invalidate() }
        readyForDisplayObservers.removeAll()
        pendingTransitionWorkItem?.cancel()
        pendingTransitionWorkItem = nil
        activeTransitionID = UUID()

        player?.pause()
        playerLayers.forEach { $0.removeFromSuperlayer() }

        player = nil
        playerLayers = []
        isPaused = false
    }

    func currentPlaybackTime() -> CMTime? {
        player?.currentTime()
    }

    /// 强制更新所有播放层的 frame
    func forceUpdateLayerFrames() {
        for layer in playerLayers {
            if let superlayer = layer.superlayer {
                layer.frame = superlayer.bounds
            }
        }
    }
}
