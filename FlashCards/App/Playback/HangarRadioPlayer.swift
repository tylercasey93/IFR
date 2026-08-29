// App/Playback/HangarRadioPlayer.swift
import AVFoundation
import Foundation
import MediaPlayer
import Observation

/// Sequential audio playback of the bundled lesson videos, podcast-style:
/// keeps playing in the background (UIBackgroundModes: audio) with
/// lock-screen transport controls. One track at a time via
/// replaceCurrentItem — no queue management, no looping.
@Observable @MainActor
final class HangarRadioPlayer {
    private(set) var lessons: [FeedLesson]
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying = false

    private let player = AVQueuePlayer()
    private var endObserver: NSObjectProtocol?
    private var commandTokens: [Any] = []

    var currentLesson: FeedLesson? {
        lessons.indices.contains(currentIndex) ? lessons[currentIndex] : nil
    }

    init(lessons: [FeedLesson]) {
        self.lessons = lessons.filter { $0.hasVideo }
    }

    func play(startingAt index: Int = 0) {
        guard lessons.indices.contains(index) else { return }
        AudioSessionConfigurator.activatePlayback()
        registerRemoteCommandsIfNeeded()
        currentIndex = index
        loadCurrentTrack()
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        AudioSessionConfigurator.activatePlayback()
        player.play()
        isPlaying = true
    }

    func next() {
        guard currentIndex + 1 < lessons.count else {
            // End of the playlist: stop cleanly rather than wrapping.
            pause()
            return
        }
        currentIndex += 1
        loadCurrentTrack()
        if isPlaying { player.play() }
    }

    func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        loadCurrentTrack()
        if isPlaying { player.play() }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        removeRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func loadCurrentTrack() {
        guard let lesson = currentLesson, let url = lesson.videoURL else { return }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        // Track-end advance via the notification API (stable, main-queue safe).
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: lesson.title,
            MPMediaItemPropertyArtist: "Hangar Radio — IFR in 30 Seconds",
        ]
    }

    private func registerRemoteCommandsIfNeeded() {
        guard commandTokens.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        commandTokens.append(center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        })
        commandTokens.append(center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        })
        commandTokens.append(center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        })
        commandTokens.append(center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        })
    }

    private func removeRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for token in commandTokens {
            center.playCommand.removeTarget(token)
            center.pauseCommand.removeTarget(token)
            center.nextTrackCommand.removeTarget(token)
            center.previousTrackCommand.removeTarget(token)
        }
        commandTokens.removeAll()
    }
}
