import Foundation

public enum LinkBattleCode {
    public static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    private static let seedMask: UInt32 = 0x3FFF_FFFF
    private static let seedCharacterCount = 6
    private static let alphabetCharacters = Array(alphabet)

    public static func encode(seed: UInt32, bankVersion: Int) -> String {
        let masked = seed & seedMask
        var characters: [Character] = []
        for shift in stride(from: (seedCharacterCount - 1) * 5, through: 0, by: -5) {
            let index = Int((masked >> shift) & 0x1F)
            characters.append(alphabetCharacters[index])
        }
        characters.append(checkCharacter(for: bankVersion))
        return String(characters)
    }

    public static func decode(_ code: String, bankVersion: Int) -> UInt32? {
        let characters = Array(code)
        guard characters.count == seedCharacterCount + 1,
              characters.last == checkCharacter(for: bankVersion) else { return nil }
        var seed: UInt32 = 0
        for character in characters.prefix(seedCharacterCount) {
            guard let index = alphabetCharacters.firstIndex(of: character) else { return nil }
            seed = (seed << 5) | UInt32(index)
        }
        return seed
    }

    public static func deck(seed: UInt32, bank: QuestionBank, scheduler: Scheduler, now: Date) -> [Question] {
        var rng = SeededRNG(seed: UInt64(seed))
        return QuizEngine(scheduler: scheduler).makeQuiz(
            config: QuizConfig(category: nil, length: 10, isMockExam: false),
            bank: bank, states: [:], now: now, using: &rng)
    }

    public static func opponent(code: String, deck: [Question]) -> Opponent {
        Opponent(id: "link-\(code)", name: "LINK PILOT", nameplateName: "LINK", spriteID: "trainer-student",
                 tier: .link, maxHP: OpponentHP.tuned(for: deck))
    }

    private static func checkCharacter(for bankVersion: Int) -> Character {
        alphabetCharacters[bankVersion % alphabetCharacters.count]
    }
}
