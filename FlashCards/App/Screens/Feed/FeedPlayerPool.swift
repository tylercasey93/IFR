// App/Screens/Feed/FeedPlayerPool.swift
import AVFoundation
import Observation

/// Keeps AVPlayers alive only for the current feed page and its neighbors,
/// TikTok-style: swiping is instant, memory stays bounded. Each player is an
/// AVQueuePlayer with an AVPlayerLooper so lesson videos loop seamlessly.
@Observable @MainActor
final class FeedPlayerPool {
    private final class Entry {
        let player: AVQueuePlayer
        let looper: AVPlayerLooper
        init(url: URL) {
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
        }
    }

    private var entries: [String: Entry] = [:]

    var isMuted = false {
        didSet {
            for entry in entries.values { entry.player.isMuted = isMuted }
        }
    }

    func player(for lessonID: String, url: URL) -> AVPlayer {
        if let existing = entries[lessonID] { return existing.player }
        let entry = Entry(url: url)
        entry.player.isMuted = isMuted
        entries[lessonID] = entry
        return entry.player
    }

    /// Plays exactly one lesson's video; pauses every other pooled player.
    func playOnly(_ lessonID: String?) {
        for (id, entry) in entries {
            if id == lessonID {
                entry.player.play()
            } else {
                entry.player.pause()
            }
        }
    }

    func restart(_ lessonID: String) {
        guard let entry = entries[lessonID] else { return }
        entry.player.seek(to: .zero)
        entry.player.play()
    }

    /// Drops players for lessons outside the keep set (current page ± 1).
    func trim(keeping lessonIDs: Set<String>) {
        for id in entries.keys where !lessonIDs.contains(id) {
            entries[id]?.player.pause()
            entries.removeValue(forKey: id)
        }
    }

    func pauseAll() {
        for entry in entries.values { entry.player.pause() }
    }
}
