// App/Playback/AudioSessionConfigurator.swift
import AVFoundation

/// Shared playback-session setup for the feed and Hangar Radio. Activation
/// matters once background audio is in play (UIBackgroundModes: audio).
enum AudioSessionConfigurator {
    static func activatePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
