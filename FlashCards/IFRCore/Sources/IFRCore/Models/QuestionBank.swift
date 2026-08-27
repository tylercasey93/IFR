import Foundation

public enum BankValidationError: Error, Equatable, Sendable {
    case duplicateID(String)
    case missingOptions(id: String)
    case badCorrectIndex(id: String)
    case badDifficulty(id: String)
    case emptyField(id: String, field: String)
    case resourceMissing
}

public struct QuestionBank: Codable, Sendable {
    public let version: Int
    public let questions: [Question]

    public init(version: Int, questions: [Question]) {
        self.version = version
        self.questions = questions
    }

    public static func load() throws -> QuestionBank {
        guard let url = Bundle.module.url(forResource: "bank-v1", withExtension: "json") else {
            throw BankValidationError.resourceMissing
        }
        let bank = try JSONDecoder().decode(QuestionBank.self, from: Data(contentsOf: url))
        try bank.validate()
        return bank
    }

    public func questions(in category: Category) -> [Question] {
        questions.filter { $0.category == category }
    }

    public func validate() throws {
        var seen = Set<String>()
        for q in questions {
            guard seen.insert(q.id).inserted else { throw BankValidationError.duplicateID(q.id) }
            if q.front.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "front") }
            if q.back.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "back") }
            if q.explanation.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "explanation") }
            if q.acsCodes.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "acsCodes") }
            guard (1...3).contains(q.difficulty) else { throw BankValidationError.badDifficulty(id: q.id) }
            if q.isMultipleChoiceCapable {
                guard let options = q.options, options.count >= 3 else {
                    throw BankValidationError.missingOptions(id: q.id)
                }
                guard let idx = q.correctIndex, options.indices.contains(idx) else {
                    throw BankValidationError.badCorrectIndex(id: q.id)
                }
            }
        }
    }
}
