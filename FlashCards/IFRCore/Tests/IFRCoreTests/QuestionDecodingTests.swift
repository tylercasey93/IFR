import XCTest
@testable import IFRCore

final class QuestionDecodingTests: XCTestCase {
    func testDecodesFullQuestion() throws {
        let json = """
        {
          "id": "reg-001",
          "category": "regulations",
          "acsCodes": ["IR.I.A.K1"],
          "format": "multipleChoice",
          "front": "To act as PIC under IFR, what instrument experience must be logged in the preceding 6 calendar months?",
          "back": "Six instrument approaches, holding procedures and tasks, and intercepting and tracking courses using navigation systems.",
          "options": [
            "Six instrument approaches, holding procedures and tasks, and intercepting/tracking courses",
            "Six hours of instrument time including three approaches",
            "Three approaches and three hours of simulated instrument time"
          ],
          "correctIndex": 0,
          "explanation": "14 CFR 61.57(c) requires the '66 HIT' items within the preceding 6 calendar months.",
          "source": {
            "document": "14 CFR 61.57(c)",
            "section": "Instrument experience",
            "url": "https://www.ecfr.gov/current/title-14/section-61.57"
          },
          "figure": null,
          "difficulty": 1
        }
        """.data(using: .utf8)!
        let q = try JSONDecoder().decode(Question.self, from: json)
        XCTAssertEqual(q.id, "reg-001")
        XCTAssertEqual(q.category, .regulations)
        XCTAssertEqual(q.format, .multipleChoice)
        XCTAssertEqual(q.correctIndex, 0)
        XCTAssertEqual(q.options?.count, 3)
        XCTAssertNil(q.figure)
    }

    func testCategoryExamWeightsSumTo60() {
        XCTAssertEqual(Category.allCases.map(\.examWeight).reduce(0, +), 60)
    }
}
