// App/Screens/Feed/HangarRadioView.swift
import SwiftUI

/// Hangar Radio: the lesson library as a background-audio playlist for the
/// drive to the airport. Sequential playback, lock-screen controls, nothing
/// fancier. Closing the sheet stops the radio; backgrounding the app doesn't.
struct HangarRadioView: View {
    let lessons: [FeedLesson]
    @State private var radio: HangarRadioPlayer
    @Environment(\.dismiss) private var dismiss

    init(lessons: [FeedLesson]) {
        self.lessons = lessons
        _radio = State(initialValue: HangarRadioPlayer(lessons: lessons))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(radio.lessons.indices, id: \.self) { index in
                        row(index)
                    }
                }
                transportBar
            }
            .navigationTitle("Hangar Radio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { radio.stop() }
    }

    private func row(_ index: Int) -> some View {
        let lesson = radio.lessons[index]
        let isCurrent = index == radio.currentIndex && radio.isPlaying
        return Button {
            radio.play(startingAt: index)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isCurrent ? "speaker.wave.2.fill" : "play.circle")
                    .foregroundStyle(isCurrent ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title).foregroundStyle(.primary)
                    Text(lesson.topicArea.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("radioLesson-\(lesson.id)")
    }

    private var transportBar: some View {
        VStack(spacing: 8) {
            Text(radio.currentLesson?.title ?? "Pick a lesson")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 44) {
                Button {
                    radio.previous()
                } label: {
                    Image(systemName: "backward.fill").font(.title2)
                }
                .accessibilityIdentifier("radioPrevious")

                Button {
                    if radio.isPlaying {
                        radio.pause()
                    } else if radio.currentLesson != nil {
                        radio.resume()
                    } else {
                        radio.play(startingAt: 0)
                    }
                } label: {
                    Image(systemName: radio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                }
                .accessibilityIdentifier("radioPlayPause")

                Button {
                    radio.next()
                } label: {
                    Image(systemName: "forward.fill").font(.title2)
                }
                .accessibilityIdentifier("radioNext")
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }
}
