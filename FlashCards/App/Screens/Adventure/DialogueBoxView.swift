import SwiftUI
import IFRCore

struct DialogueBoxView: View {
    let script: DialogueScript
    let scale: Int
    let displayScale: CGFloat
    var onFinished: () -> Void = {}

    @State private var pageIndex = 0
    @State private var phaseStart = Date()

    private var pages: [TypewriterPage] {
        script.pages.flatMap { Typewriter.paginate($0) }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let frame = frameIndex(at: context.date)
            let page = currentPage
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(visibleLines(of: page, atFrame: frame).enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            .font(RetroTheme.pixelFont(size: RetroTheme.pixelFontSize(scale: scale, displayScale: displayScale)))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { advance(atFrame: frame) }
        }
    }

    private var currentPage: TypewriterPage {
        pages.indices.contains(pageIndex) ? pages[pageIndex] : TypewriterPage(lines: [])
    }

    private func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(phaseStart) * 60))
    }

    private func visibleLines(of page: TypewriterPage, atFrame frame: Int) -> [String] {
        var remaining = Typewriter.visibleCharacters(of: page, atFrame: frame, holding: false)
        return page.lines.map { line in
            let count = min(remaining, line.count)
            remaining -= count
            return String(line.prefix(count))
        }
    }

    private func advance(atFrame frame: Int) {
        Haptics.tick()
        guard Typewriter.isComplete(currentPage, atFrame: frame, holding: false) else { return }
        if pageIndex + 1 < pages.count {
            pageIndex += 1
            phaseStart = Date()
        } else {
            onFinished()
        }
    }
}
