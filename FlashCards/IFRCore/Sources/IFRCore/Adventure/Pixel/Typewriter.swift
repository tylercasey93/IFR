import Foundation

public struct TypewriterPage: Equatable, Sendable {
    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }
}

public enum Typewriter {
    public static func paginate(_ text: String, columns: Int = 28, rows: Int = 2) -> [TypewriterPage] {
        let wrapped = wrappedLines(text, columns: columns)
        return stride(from: 0, to: wrapped.count, by: rows).map { start in
            let end = min(start + rows, wrapped.count)
            return TypewriterPage(lines: Array(wrapped[start..<end]))
        }
    }

    public static func revealCost(of page: TypewriterPage, holding: Bool) -> [Int] {
        var costs: [Int] = []
        var running = 0
        var previous: Character?
        for character in page.lines.joined() {
            running += step(after: previous, holding: holding)
            costs.append(running)
            previous = character
        }
        return costs
    }

    public static func visibleCharacters(of page: TypewriterPage, atFrame: Int, holding: Bool) -> Int {
        revealCost(of: page, holding: holding).filter { $0 <= atFrame }.count
    }

    public static func isComplete(_ page: TypewriterPage, atFrame: Int, holding: Bool) -> Bool {
        guard let last = revealCost(of: page, holding: holding).last else { return true }
        return atFrame >= last
    }

    public static func cursorVisible(atFrame: Int) -> Bool {
        let period = 30
        let cycle = ((atFrame % period) + period) % period
        return cycle < period / 2
    }

    private static func step(after previous: Character?, holding: Bool) -> Int {
        let base = holding ? 1 : 2
        return base + pause(after: previous, holding: holding)
    }

    private static func pause(after previous: Character?, holding: Bool) -> Int {
        guard !holding, let previous else { return 0 }
        if ".?!".contains(previous) { return 8 }
        if previous == "," { return 4 }
        return 0
    }

    private static func wrappedLines(_ text: String, columns: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let candidate = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            if candidate.count > columns {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = candidate
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines
    }
}
