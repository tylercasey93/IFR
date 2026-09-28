import SwiftUI
import IFRCore

struct OverworldScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    let content: AdventureContent
    let seed: UInt64?
    var onBattleFinished: () -> Void = {}

    @State private var model: OverworldScreenModel?
    @State private var showingMap = false

    var body: some View {
        Group {
            if let model {
                canvas(model: model)
            } else {
                Color.clear.onAppear { model = makeModel() }
            }
        }
        .toolbar {
            ToolbarItem { Button("Map") { showingMap = true }.accessibilityIdentifier("regionMapButton") }
        }
        .sheet(isPresented: $showingMap) {
            RegionMapScreen(content: content, onSelect: { airport in warp(to: airport) })
        }
        .navigationDestination(isPresented: eliteFourBinding()) { EliteFourScreen(content: content) }
        .navigationDestination(isPresented: championBinding()) { ChampionScreen(content: content) }
    }

    private func makeModel() -> OverworldScreenModel {
        guard let seed else { return OverworldScreenModel(content: content, store: store) }
        return OverworldScreenModel(content: content, store: store, makeRNG: { SeededRNG(seed: seed) })
    }

    private func canvas(model: OverworldScreenModel) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let scale = canvasScale(in: geometry.size)
                let size = canvasSize(scale: scale)
                let frame = OverworldRenderer.frame(
                    map: model.map, state: model.state, trainers: content.trainers,
                    defeated: model.save.defeatedTrainerIDs, atFrame: model.frameIndex(at: context.date))
                ZStack(alignment: .bottomLeading) {
                    GBAScreen(frame: frame)
                    if let dialogue = model.dialogue {
                        DialogueBoxView(script: dialogue, scale: scale, displayScale: displayScale,
                                       onFinished: { model.dialogueFinished() })
                    }
                    if let gymID = model.challengeableGymID {
                        Button("Challenge") { model.challengeGym() }
                            .accessibilityIdentifier("gym-\(gymID.rawValue)")
                    }
                    if store.settings.dpadEnabled {
                        DPadOverlay(onPress: { model.dpadStep($0) })
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(tapGesture(model: model, viewSize: size))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("overworldScreen")
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .onChange(of: context.date) { _, date in model.advance(at: date) }
            }
        }
        .background(Theme.panel)
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.sceneDidEnterBackground() } }
        .onChange(of: model.showingEliteFour) { _, showing in if !showing { model.eliteFourDismissed() } }
        .onChange(of: model.showingChampion) { _, showing in if !showing { model.championDismissed() } }
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run).onDisappear {
                model.battleDismissed()
                onBattleFinished()
            }
        }
    }

    private func canvasScale(in available: CGSize) -> Int {
        IntegerScaler.scale(viewWidth: available.width, viewHeight: available.height, displayScale: displayScale)
    }

    private func canvasSize(scale: Int) -> CGSize {
        let size = IntegerScaler.canvasSize(scale: scale, displayScale: displayScale)
        return CGSize(width: size.width, height: size.height)
    }

    private func tapGesture(model: OverworldScreenModel, viewSize: CGSize) -> some Gesture {
        SpatialTapGesture().onEnded { event in
            model.tapped(at: event.location, viewSize: viewSize, displayScale: displayScale)
        }
    }

    private func activeBattleBinding(_ model: OverworldScreenModel) -> Binding<BattleRun?> {
        Binding(get: { model.activeBattle }, set: { newValue in if newValue == nil { model.clearActiveBattle() } })
    }

    private func eliteFourBinding() -> Binding<Bool> {
        Binding(get: { model?.showingEliteFour ?? false }, set: { model?.showingEliteFour = $0 })
    }

    private func championBinding() -> Binding<Bool> {
        Binding(get: { model?.showingChampion ?? false }, set: { model?.showingChampion = $0 })
    }

    private func warp(to airport: Airport) {
        guard let destination = DirectTo.destination(of: airport, in: model?.map ?? content.tileMap ?? TileMap(width: 1, height: 1, rows: [[.ground]])) else { return }
        model?.warpTo(destination)
    }
}
