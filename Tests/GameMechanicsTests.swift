import XCTest
#if SWIFT_PACKAGE
@testable import UniversityAfterDarkCore
#else
@testable import UniversityAfterDark
#endif

final class GameMechanicsTests: XCTestCase {
    func players(_ count: Int = 3) -> [Player] { (0..<count).map { Player(name: "Guest \($0)") } }
    func testNoRepeatsUntilExhaustionForEveryPool() throws {
        let bank = try QuestionBank.load().questions
        for round in 1...5 {
            for type in QuestionType.allCases {
                let pool = bank.filter { $0.round == round && $0.type == type }
                var randomizer = QuestionRandomizer()
                var seen = Set<String>()
                for _ in pool {
                    let q = try XCTUnwrap(randomizer.draw(from: pool))
                    XCTAssertTrue(seen.insert(q.id).inserted)
                }
                XCTAssertNil(randomizer.draw(from: pool))
            }
        }
    }
    func testOverlappingPoolsAndModeChangesPreserveHistory() throws {
        let bank = try QuestionBank.load().questions
        var session = GameSession(players: players(), settings: GameSettings())
        let first = try XCTUnwrap(session.draw(type: .truth, bank: bank))
        session.finishQuestion(skipped: false)
        session.settings.mode = .absoluteChaos; session.settings.round = 4
        let stats = session.statistics
        let second = try XCTUnwrap(session.draw(type: .truth, bank: bank))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(session.randomizer.usedIDs.contains(first.id))
        XCTAssertEqual(session.statistics.turns, stats.turns)
        XCTAssertEqual(session.statistics.truths, 1)
    }
    func testResetPoolAvoidsImmediateRepeatAndKeepsOtherHistory() throws {
        let bank = try QuestionBank.load().questions
        let pool = Array(bank.filter { $0.type == .truth && $0.round == 1 }.prefix(2))
        let outside = bank.filter { $0.type == .dare && $0.round == 2 }
        var randomizer = QuestionRandomizer()
        let other = try XCTUnwrap(randomizer.draw(from: outside))
        _ = randomizer.draw(from: pool)
        let last = try XCTUnwrap(randomizer.draw(from: pool))
        XCTAssertNil(randomizer.draw(from: pool))
        randomizer.reset(pool: pool)
        XCTAssertTrue(randomizer.usedIDs.contains(other.id))
        XCTAssertNotEqual(randomizer.draw(from: pool)?.id, last.id)
    }
    func testEmptyPoolReturnsNil() { var bag = QuestionRandomizer(); XCTAssertNil(bag.draw(from: [])) }
    func testSequentialTurnRotationAndNextPlayer() {
        let group = players()
        var session = GameSession(players: group, settings: GameSettings())
        for turn in 0..<30 {
            XCTAssertEqual(session.currentPlayerID, group[turn % 3].id)
            XCTAssertEqual(session.nextPlayer?.id, group[(turn + 1) % 3].id)
            session.advance()
        }
    }
    func testRemovingCurrentNextAndLastPlayerIsSafe() {
        let group = players(4)
        var session = GameSession(players: group, settings: GameSettings())
        session.replacePlayers(Array(group.dropFirst()))
        XCTAssertEqual(session.currentPlayerID, group[1].id)
        session.selectPlayer(group[3].id)
        session.replacePlayers(Array(group[1...2]))
        XCTAssertNotNil(session.currentPlayer)
        for _ in 0..<15 { session.advance(); XCTAssertNotNil(session.currentPlayer); XCTAssertNotNil(session.nextPlayer) }
    }
    func testShuffledOrderIsAPermutationAndNextPreviewIsReliable() {
        var settings = GameSettings(); settings.order = .shuffled
        let group = players(20)
        var session = GameSession(players: group, settings: settings)
        for _ in 0..<5 {
            var ids = Set<UUID>()
            for _ in 0..<20 {
                ids.insert(session.currentPlayerID!)
                let preview = session.nextPlayer?.id
                session.advance()
                XCTAssertEqual(session.currentPlayerID, preview)
            }
            XCTAssertEqual(ids, Set(group.map(\.id)))
        }
    }
    func testManualSelectionReorderingAndRotationRestart() {
        let group = players()
        var session = GameSession(players: group, settings: GameSettings())
        session.selectPlayer(group[2].id); XCTAssertEqual(session.currentPlayerID, group[2].id)
        session.replacePlayers(group.reversed()); XCTAssertEqual(session.currentPlayerID, group[2].id)
        session.advance(); XCTAssertEqual(session.currentPlayerID, group[1].id)
        session.restartRotation(); XCTAssertEqual(session.currentPlayerID, group[2].id)
    }
    func testPlayerValidationAndBoundarySizes() {
        XCTAssertNil(PlayerValidation.error(for: players(2)))
        XCTAssertNil(PlayerValidation.error(for: players(20)))
        XCTAssertNotNil(PlayerValidation.error(for: players(1)))
        XCTAssertNotNil(PlayerValidation.error(for: players(21)))
        XCTAssertNotNil(PlayerValidation.error(for: [Player(name: "  "), Player(name: "Alex")]))
        XCTAssertNotNil(PlayerValidation.error(for: [Player(name: " álex "), Player(name: "ALEX")]))
    }
    func testEscalationRisesEveryRotationAndStopsAtTen() {
        var settings = GameSettings(); settings.mode = .escalation
        var session = GameSession(players: players(2), settings: settings)
        for turn in 0..<15 {
            session.statistics.turns = turn
            XCTAssertEqual(session.effectiveRound, min(4, 1 + turn / 2))
        }
    }
    func testNuclearPoolNeverContainsIndividualQuestions() throws {
        var settings = GameSettings(); settings.mode = .nuclear
        let session = GameSession(players: players(), settings: settings)
        XCTAssertEqual(session.effectiveRound, 5)
        let pool = session.pool(type: .nuclear, bank: try QuestionBank.load().questions)
        XCTAssertEqual(pool.count, 18)
        XCTAssertTrue(pool.allSatisfy { $0.type == .nuclear })
    }
    func testRedrawKeepsTypeAndIntensityEvenInChaos() throws {
        var settings = GameSettings(); settings.mode = .absoluteChaos; settings.round = 4
        var session = GameSession(players: players(), settings: settings)
        let bank = try QuestionBank.load().questions
        let first = try XCTUnwrap(session.draw(type: .dare, bank: bank))
        let second = try XCTUnwrap(session.draw(type: .dare, bank: bank, replacing: true))
        XCTAssertEqual(first.intensity, second.intensity)
        XCTAssertEqual(first.type, second.type)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(session.statistics.drawn, 2)
        XCTAssertEqual(session.statistics.turns, 0)
    }
    func testRapidDuplicateActionsAreIdempotent() throws {
        var session = GameSession(players: players(), settings: GameSettings())
        let bank = try QuestionBank.load().questions
        XCTAssertNotNil(session.draw(type: .truth, bank: bank))
        for _ in 0..<20 { XCTAssertNil(session.draw(type: .dare, bank: bank)) }
        for _ in 0..<20 { session.finishQuestion(skipped: false) }
        XCTAssertEqual(session.statistics.drawn, 1)
        XCTAssertEqual(session.statistics.turns, 1)
        XCTAssertEqual(session.statistics.truths, 1)
    }
    func testSkipHasNoPenaltyAndStatisticsTrackAllTypes() throws {
        var session = GameSession(players: players(2), settings: GameSettings())
        let bank = try QuestionBank.load().questions
        for type in QuestionType.allCases {
            _ = session.draw(type: type, bank: bank); session.finishQuestion(skipped: false)
        }
        _ = session.draw(type: .truth, bank: bank); session.finishQuestion(skipped: true)
        XCTAssertEqual(session.statistics.truths, 1); XCTAssertEqual(session.statistics.dares, 1)
        XCTAssertEqual(session.statistics.nuclear, 1); XCTAssertEqual(session.statistics.skipped, 1)
        XCTAssertEqual(session.statistics.turns, 4)
    }
}
