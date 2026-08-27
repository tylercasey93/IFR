// App/Screens/Feed/FeedVideoCard.swift
import AVFoundation
import SwiftUI

/// One video page of the feed: full-bleed looping player with a light overlay
/// (title, topic, sources, mute) — the video itself carries the content.
struct FeedVideoCard: View {
    let lesson: FeedLesson
    let isActive: Bool
    @Environment(FeedPlayerPool.self) private var pool
    @State private var showSources = false

    var body: some View {
        ZStack {
            if let url = lesson.videoURL {
                PlayerLayerView(player: pool.player(for: lesson.id, url: url))
                    .onTapGesture { pool.restart(lesson.id) }
            } else {
                missingVideo
            }
            overlay
        }
        .background(Color.black)
        .sheet(isPresented: $showSources) {
            FeedSourcesSheet(lesson: lesson)
                .presentationDetents([.medium])
        }
    }

    private var overlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.topicArea.uppercased())
                        .placard()
                    Text(lesson.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .shadow(radius: 6)
                }
                Spacer()
                VStack(spacing: 18) {
                    overlayButton(systemImage: "text.book.closed.fill",
                                  label: "Sources",
                                  identifier: "feedSourcesButton") {
                        showSources = true
                    }
                    overlayButton(systemImage: pool.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                  label: pool.isMuted ? "Unmute" : "Mute",
                                  identifier: "feedMuteButton") {
                        pool.isMuted.toggle()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func overlayButton(systemImage: String, label: String, identifier: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var missingVideo: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(lesson.hook)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Video not bundled yet — run the render pipeline.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel.gradient)
    }
}
