import XCTest
#if SWIFT_PACKAGE
@testable import UniversityAfterDarkCore
#else
@testable import UniversityAfterDark
#endif

final class QuestionBankTests: XCTestCase {
    func testBundledJSONLoadsAndHas197UniqueQuestions() throws {
        let questions = try QuestionBank.load().questions
        XCTAssertEqual(questions.count, 197)
        XCTAssertEqual(Set(questions.map(\.id)).count, 197)
        XCTAssertTrue(questions.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        try QuestionBank.validate(questions, bundled: true)
    }
    func testAllOriginalAndAdditionalCategoryCounts() throws {
        let questions = try QuestionBank.load().questions
        let original = [[10, 8], [15, 8], [15, 8], [15, 8]]
        let additional = [[10, 10], [12, 10], [15, 10], [15, 10]]
        for round in 1...4 {
            for (index, type) in [QuestionType.truth, .dare].enumerated() {
                XCTAssertEqual(questions.filter { $0.round == round && $0.type == type && $0.isOriginal }.count, original[round-1][index])
                XCTAssertEqual(questions.filter { $0.round == round && $0.type == type && !$0.isOriginal }.count, additional[round-1][index])
            }
        }
        XCTAssertEqual(questions.filter { $0.type == .nuclear && $0.isOriginal }.count, 8)
        XCTAssertEqual(questions.filter { $0.type == .nuclear && !$0.isOriginal }.count, 10)
        XCTAssertEqual(questions.filter(\.isOriginal).count, 95)
        XCTAssertEqual(questions.filter { !$0.isOriginal }.count, 102)
    }
    func testCategoriesIntensitiesAndTitlesAreValid() throws {
        let questions = try QuestionBank.load().questions
        for q in questions {
            XCTAssertEqual(q.intensity, Rounds.intensity(q.round))
            XCTAssertEqual(q.type == .nuclear, q.round == 5)
            if q.type == .nuclear || (q.type == .dare && q.round == 4) { XCTAssertNotNil(q.title) }
        }
    }
    func testOriginalWordingIsPreserved() throws {
        let questions = try QuestionBank.load().questions
        XCTAssertEqual(questions.first { $0.id == "original_dare_r4_003" }?.text, "Sit in the middle while everyone asks one uncomfortable question. Answer at least three.")
        XCTAssertEqual(questions.first { $0.id == "original_nuclear_r5_001" }?.text, "Everyone secretly writes down the person in the room they find most attractive.\n\nReveal only the vote totals, with everyone's agreement.")
    }
    func testValidationRejectsDuplicateIDsEmptyTextAndInvalidCategories() throws {
        var question = try XCTUnwrap(QuestionBank.load().questions.first)
        XCTAssertThrowsError(try QuestionBank.validate([question, question]))
        question.text = " \n "
        XCTAssertThrowsError(try QuestionBank.validate([question]))
        question.text = "Valid text"; question.intensity = 7
        XCTAssertThrowsError(try QuestionBank.validate([question]))
        question.intensity = 10; question.round = 5; question.type = .truth
        XCTAssertThrowsError(try QuestionBank.validate([question]))
    }
    func testVeryLongCustomTextIsNotTruncated() throws {
        var question = try XCTUnwrap(QuestionBank.load().questions.first)
        question.id = "custom_" + UUID().uuidString
        question.text = String(repeating: "A deliberately long and completely optional question. ", count: 200)
        try QuestionBank.validate([question])
        let decoded = try JSONDecoder().decode(Question.self, from: JSONEncoder().encode(question))
        XCTAssertEqual(decoded.text, question.text)
    }
}
