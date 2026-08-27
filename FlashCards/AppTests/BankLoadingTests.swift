// AppTests/BankLoadingTests.swift
import XCTest
import IFRCore

final class BankLoadingTests: XCTestCase {
    func testBankLoadsInsideAppBundle() throws {
        let bank = try QuestionBank.load()
        XCTAssertGreaterThanOrEqual(bank.questions.count, 8)
    }
}
