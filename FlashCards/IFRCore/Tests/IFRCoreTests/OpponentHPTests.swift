import XCTest
@testable import IFRCore

final class OpponentHPTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    func testTunedHPIsSeventyPercentOfTotalBaseDamageRoundedUp() {
        let ten = (0..<10).map { mcQuestion("q\($0)", .weather, difficulty: 2) }
        XCTAssertEqual(OpponentHP.tuned(for: ten), 70)

        let three = (0..<3).map { mcQuestion("q\($0)", .weather, difficulty: 1) }
        XCTAssertEqual(OpponentHP.tuned(for: three), 17)
    }

    func testCloudHPEqualsBaseDamageOfItsQuestion() {
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d1", .weather, difficulty: 1)), 8)
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d2", .weather, difficulty: 2)), 10)
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d3", .weather, difficulty: 3)), 12)
    }
}
