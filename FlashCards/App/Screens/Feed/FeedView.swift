// App/Screens/Feed/FeedView.swift
import AVFoundation
import IFRCore
import SwiftUI

/// "IFR in 30 Seconds": a TikTok-style vertical pager of ~30-second animated
/// lesson videos with pre-flight challenge cards before and quiz pages after
/// each one. iOS 17 paging ScrollView; players are pooled for the current
/// page ± 1. Page order is spaced-repetition-aware (FeedOrdering), computed
/// once per visit so pages never reshuffle mid-scroll.
struct FeedView: View {
    @State private var items: [FeedItem] = []
    @State private var currentID: String?
    @State private var pool = FeedPlayerPool()
    @State private var showBrowse = false
    @State private var showRadio = false
    @Environment(FeedProgressStore.self) private var progress
    @Environment(StudyStore.self) private var store
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
        .onAppear {
            AudioSessionConfigurator.activatePlayback()
            if items.isEmpty {
                let lessons = FeedOrdering.ordered(FeedContent.load()) { lesson in
                    .init(watchedAt: progress.watchedDate(lesson.id),
                          hasWrongLatestAnswer: progress.hasWrongLatestAnswer(lesson))
                }
                items = FeedContent.buildItems(from: lessons)
                currentID = items.first?.id
            }
            activate(currentID)
        }
        .onDisappear {
            pool.pauseAll()
            progress.sessionStreak = 0
        }
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
        .overlay(alignment: .topTrailing) { overlayButtons }
        .sheet(isPresented: $showBrowse) {
            FeedBrowseSheet(lessons: uniqueLessons) { lessonID in
                showBrowse = false
                currentID = lessonID
            }
        }
        .sheet(isPresented: $showRadio, onDismiss: { activate(currentID) }) {
            HangarRadioView(lessons: uniqueLessons)
        }
        .accessibilityIdentifier("feedPager")
    }

    @ViewBuilder
    private func page(for item: FeedItem) -> some View {
        switch item {
        case .preflight(let lesson):
            FeedPreflightCard(lesson: lesson)
        case .video(let lesson):
            FeedVideoCard(lesson: lesson, isActive: currentID == lesson.id)
        case .quiz(let lesson, let index):
            FeedQuizCard(lesson: lesson, questionIndex: index)
        }
    }

    private var overlayButtons: some View {
        VStack(spacing: 14) {
            overlayButton(systemImage: "list.bullet", identifier: "feedBrowseButton") {
                showBrowse = true
            }
            overlayButton(systemImage: "dot.radiowaves.left.and.right", identifier: "hangarRadioButton") {
                pool.pauseAll()
                showRadio = true
            }
        }
        .padding(.trailing, 20)
        .padding(.top, 60)
    }

    private func overlayButton(systemImage: String, identifier: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
        // While Hangar Radio is up, the feed stays silent — the scenePhase
        // path must not restart video audio over the radio.
        guard !showRadio else { return }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            pool.pauseAll()
            return
        }
        let item = items[index]

        // Warm players for the neighboring video pages so swipes start instantly.
        var keep = Set<String>()
        for offset in -2...2 {
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
            if !progress.isWatched(lesson.id) {
                progress.markWatched(lesson.id)
                store.awardFeedXP(.feedLessonWatched, reason: "feedWatch")
            }
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
