import Foundation

extension AdventureContent {
    func checkDialogueReferences() throws {
        var owners: [(String, DialogueRefs)] = gyms.map { ($0.id.rawValue, $0.dialogue) }
        owners += eliteFour.map { ($0.id, $0.dialogue) }
        owners.append((champion.name, champion.dialogue))
        for (owner, refs) in owners {
            for key in [refs.intro, refs.win, refs.lose] {
                guard let script = dialogue[key] else {
                    throw AdventureContentError.unknownReference(from: owner, to: key)
                }
                guard !script.pages.isEmpty, script.pages.allSatisfy({ !$0.isEmpty }) else {
                    throw AdventureContentError.emptyDialogue(key)
                }
            }
        }
    }

    func checkDialoguePageLengths() throws {
        for (key, script) in dialogue {
            for page in script.pages where Typewriter.paginate(page).count != 1 {
                throw AdventureContentError.dialoguePageTooLong(key)
            }
        }
    }

    func checkSystemDialogueKeys() throws {
        for key in SystemDialogueKey.allCases where system[key.rawValue] == nil {
            throw AdventureContentError.unknownReference(from: "system", to: key.rawValue)
        }
    }

    func checkSystemDialogueSubstitution() throws {
        let values = longestSubstitutionValues()
        for key in SystemDialogueKey.allCases {
            let filled = systemLine(key, filling: values)
            for page in filled.pages where Typewriter.paginate(page).count != 1 {
                throw AdventureContentError.dialoguePageTooLong(key.rawValue)
            }
        }
    }

    private func longestSubstitutionValues() -> [String: String] {
        [
            "badge": gyms.map(\.badgeName).max(by: { $0.count < $1.count }) ?? "",
            "leader": gyms.map(\.leaderName).max(by: { $0.count < $1.count }) ?? "",
            "airport": region.airports.map(\.id).max(by: { $0.count < $1.count }) ?? "",
            "opponent": opponentNames().max(by: { $0.count < $1.count }) ?? "",
        ]
    }

    func checkNameplateLengths() throws {
        var plates: [(String, String)] = gyms.map { ($0.id.rawValue, $0.nameplateName) }
        plates += eliteFour.map { ($0.id, $0.nameplateName) }
        plates.append((champion.name, champion.nameplateName))
        for (owner, nameplate) in plates where nameplate.count > 7 {
            throw AdventureContentError.nameplateTooLong(owner)
        }
    }

    func checkEliteFourCoverage() throws {
        var seen: Set<Category> = []
        for member in eliteFour {
            for category in member.categories {
                guard seen.insert(category).inserted else {
                    throw AdventureContentError.duplicateID(category.rawValue)
                }
            }
        }
        for category in Category.allCases where !seen.contains(category) {
            throw AdventureContentError.unknownReference(from: "eliteFour", to: category.rawValue)
        }
    }

    func checkGymQuestionPools() throws {
        let bank = try QuestionBank.load()
        for gym in gyms {
            let pool = bank.questions(in: gym.id.category).filter(\.isMultipleChoiceCapable)
            guard pool.count >= gym.questionCount else {
                throw AdventureContentError.notEnoughQuestions(gymID: gym.id.rawValue)
            }
        }
    }

    func checkSpriteReferences() throws {
        var sprites: [String] = gyms.map(\.leaderSpriteID) + eliteFour.map(\.spriteID)
        sprites.append(champion.spriteID)
        for spriteID in sprites where SpriteCatalog.sprite(named: spriteID) == nil {
            throw AdventureContentError.unknownSprite(spriteID)
        }
    }
}
