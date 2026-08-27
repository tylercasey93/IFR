// App/Screens/Feed/FeedView.swift
import AVFoundation
import SwiftUI

/// "IFR in 30 Seconds": a TikTok-style vertical pager of ~30-second animated
/// lesson videos with quiz pages interleaved after each one. iOS 17 paging
/// ScrollView; players are pooled for the current page ± 1.
struct FeedView: View {
    @State private var items: [FeedItem] = []
    @State private var currentID: String?
    @State private var pool = FeedPlayerPool()
    @State private var progress = FeedProgressStore()
    @State private var showBrowse = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                pager
            }
        }
        .environment(pool)
        .environment(progress)
        .onAppear {
            // Scoped here (not app-wide): the feed is the only AV playback,
            // and .playback lets narration play past the silent switch.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            if items.isEmpty {
                items = FeedContent.buildItems(from: FeedContent.load())
                currentID = items.first?.id
            }
            activate(currentID)
        }
        .onDisappear { pool.pauseAll() }
        .onChange(of: currentID) { _, newValue in activate(newValue) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pool.pauseAll() } else { activate(currentID) }
        }
    }

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    page(for: item)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .clipped()
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
        .overlay(alignment: .topTrailing) { browseButton }
        .sheet(isPresented: $showBrowse) {
            FeedBrowseSheet(lessons: uniqueLessons) { lessonID in
                showBrowse = false
                currentID = lessonID
            }
            .environment(progress)
        }
        .accessibilityIdentifier("feedPager")
    }

    @ViewBuilder
    private func page(for item: FeedItem) -> some View {
        switch item {
        case .video(let lesson):
            FeedVideoCard(lesson: lesson, isActive: currentID == lesson.id)
        case .quiz(let lesson, let index):
            FeedQuizCard(lesson: lesson, questionIndex: index)
        }
    }

    private var browseButton: some View {
        Button {
            showBrowse = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 60)
        .accessibilityIdentifier("feedBrowseButton")
    }

    private var uniqueLessons: [FeedLesson] {
        var seen = Set<String>()
        return items.compactMap { item in
            guard case .video(let lesson) = item, seen.insert(lesson.id).inserted else { return nil }
            return lesson
        }
    }

    /// Drives playback + preloading + progress whenever the visible page changes.
    private func activate(_ itemID: String?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            pool.pauseAll()
            return
        }
        let item = items[index]

        // Warm players for the neighboring video pages so swipes start instantly.
        var keep = Set<String>()
        for offset in -1...1 {
            let neighbor = index + offset
            guard items.indices.contains(neighbor),
                  case .video(let lesson) = items[neighbor],
                  let url = lesson.videoURL else { continue }
            _ = pool.player(for: lesson.id, url: url)
            keep.insert(lesson.id)
        }
        pool.trim(keeping: keep)

        if case .video(let lesson) = item {
            pool.playOnly(lesson.id)
            progress.markWatched(lesson.id)
        } else {
            pool.playOnly(nil)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No lessons bundled")
                .font(.title3.weight(.semibold))
            Text("Run the video pipeline's app:content step to package FeedMedia, then rebuild.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel.gradient)
    }
}
