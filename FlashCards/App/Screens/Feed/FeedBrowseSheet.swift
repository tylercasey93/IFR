// App/Screens/Feed/FeedBrowseSheet.swift
import SwiftUI

/// Topic-grouped list of feed lessons with watched/passed state; tapping one
/// jumps the pager to that lesson.
struct FeedBrowseSheet: View {
    let lessons: [FeedLesson]
    let onSelect: (String) -> Void
    @Environment(FeedProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss

    /// Topic areas in their first-appearance (feed) order.
    private var topics: [String] {
        var seen = Set<String>()
        return lessons.compactMap { seen.insert($0.topicArea).inserted ? $0.topicArea : nil }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(topics, id: \.self) { topic in
                    Section(topic.capitalized) {
                        ForEach(lessons.filter { $0.topicArea == topic }) { lesson in
                            row(lesson)
                        }
                    }
                }
            }
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ lesson: FeedLesson) -> some View {
        Button {
            onSelect(lesson.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: progress.isWatched(lesson.id) ? "play.circle.fill" : "play.circle")
                    .foregroundStyle(progress.isWatched(lesson.id) ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .foregroundStyle(.primary)
                    Text(lesson.references.faa.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if progress.passedQuiz(lesson) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .accessibilityIdentifier("feedLesson-\(lesson.id)")
    }
}
