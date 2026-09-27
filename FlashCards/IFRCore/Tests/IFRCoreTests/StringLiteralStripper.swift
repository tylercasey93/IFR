struct StringLiteralStripper {
    private let characters: [Character]
    private var index = 0
    private var code = ""

    static func strip(_ text: String) -> String {
        var stripper = StringLiteralStripper(characters: Array(text))
        return stripper.stripped()
    }

    private init(characters: [Character]) {
        self.characters = characters
    }

    private mutating func stripped() -> String {
        while index < characters.count {
            if characters[index] == "\"" {
                skipLiteral()
            } else {
                code.append(characters[index])
                index += 1
            }
        }
        return code
    }

    private func hasTripleQuote(at position: Int) -> Bool {
        position + 2 < characters.count
            && characters[position...(position + 2)].allSatisfy { $0 == "\"" }
    }

    private mutating func skipLiteral() {
        let delimiterLength = hasTripleQuote(at: index) ? 3 : 1
        index += delimiterLength
        while index < characters.count {
            if characters[index] == "\\" {
                skipEscape()
            } else if closesLiteral(delimiterLength: delimiterLength) {
                index += delimiterLength
                return
            } else {
                index += 1
            }
        }
    }

    private func closesLiteral(delimiterLength: Int) -> Bool {
        delimiterLength == 3 ? hasTripleQuote(at: index) : characters[index] == "\""
    }

    private mutating func skipEscape() {
        index += 1
        guard index < characters.count else { return }
        if characters[index] == "(" {
            skipInterpolation()
        } else {
            index += 1
        }
    }

    private mutating func skipInterpolation() {
        var depth = 0
        repeat {
            if characters[index] == "\"" {
                skipLiteral()
                continue
            }
            depth += characters[index] == "(" ? 1 : characters[index] == ")" ? -1 : 0
            index += 1
        } while depth > 0 && index < characters.count
    }
}
