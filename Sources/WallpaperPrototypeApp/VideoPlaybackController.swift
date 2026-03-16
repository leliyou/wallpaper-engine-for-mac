import AppKit
import AVFoundation

@MainActor
final class VideoPlaybackController {
    var onFailure: ((String) -> Void)?
    var onPlaybackEnded: (() -> Void)?

    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayers: [AVPlayerLayer] = []
    private var playbackEndObserver: NSObjectProtocol?
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
        stop()

        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        let player: AVPlayer

        if enableSeamlessLoop {
            let queuePlayer = AVQueuePlayer()
            playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
        } else {
            player = AVPlayer(playerItem: item)
        }

        var layers: [AVPlayerLayer] = []
        for hostView in hostViews {
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = videoGravity
            layer.frame = hostView.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            hostView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            hostView.layer?.addSublayer(layer)
            layers.append(layer)
        }

        if !enableSeamlessLoop {
            playbackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onPlaybackEnded?()
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

        player?.pause()
        playerLayers.forEach { $0.removeFromSuperlayer() }

        player = nil
        playerLooper = nil
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
