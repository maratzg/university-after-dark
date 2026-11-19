import XCTest
#if SWIFT_PACKAGE
@testable import UniversityAfterDarkCore
#else
@testable import UniversityAfterDark
#endif

final class PersistenceAndToolsTests: XCTestCase {
    var defaults: UserDefaults!
    var suite: String!
    override func setUp() {
        suite = "UniversityAfterDark.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    func makeSession() -> GameSession { GameSession(players: [Player(name: "Alex"), Player(name: "Emma")], settings: GameSettings()) }
    func testPersistenceAndResumeKeepQuestionPlayerBagsAndStatistics() throws {
        let store = PersistenceStore(defaults: defaults)
        var session = makeSession()
        let bank = try QuestionBank.load().questions
        _ = session.draw(type: .truth, bank: bank)
        session.finishQuestion(skipped: false)
        _ = session.draw(type: .dare, bank: bank)
        var state = SavedState(); state.session = session; state.players = session.players
        try store.save(state)
        let restored = try XCTUnwrap(store.load())
        XCTAssertEqual(restored.session, session)
        var resumed = restored.session!
        let current = resumed.currentQuestion!
        resumed.finishQuestion(skipped: false)
        let newQuestion = try XCTUnwrap(resumed.draw(type: .dare, bank: bank))
        XCTAssertNotEqual(current.id, newQuestion.id)
    }
    func testResetRemovesSavedSession() throws {
        let store = PersistenceStore(defaults: defaults)
        var state = SavedState(); state.session = makeSession()
        try store.save(state); store.reset(); XCTAssertNil(try store.load())
    }
    func testCorruptPersistenceReportsFailureAndKeepsData() {
        let store = PersistenceStore(defaults: defaults)
        defaults.set(Data("invalid".utf8), forKey: store.key)
        XCTAssertThrowsError(try store.load())
        XCTAssertNotNil(defaults.data(forKey: store.key))
    }
    func testInvalidSavedRotationIsRejected() throws {
        let store = PersistenceStore(defaults: defaults)
        var state = SavedState(); state.session = makeSession(); state.session?.position = 99
        try store.save(state); XCTAssertThrowsError(try store.load())
    }
    func testCustomQuestionsPersistAndAreRemoved() throws {
        let store = PersistenceStore(defaults: defaults)
        var state = SavedState()
        var custom = try XCTUnwrap(QuestionBank.load().questions.first)
        custom.id = "custom_\(UUID().uuidString)"; custom.isOriginal = false
        state.customQuestions.append(custom); try store.save(state)
        XCTAssertEqual(try store.load()?.customQuestions.first, custom)
        state.customQuestions.removeAll { $0.id == custom.id }; try store.save(state)
        XCTAssertTrue(try XCTUnwrap(store.load()).customQuestions.isEmpty)
    }
    func testTimerPauseResumeResetAndCompletionUseElapsedTime() {
        var timer = CountdownState(); timer.configure(seconds: 30)
        timer.start(at: 10); XCTAssertEqual(timer.remaining(at: 15), 25)
        timer.pause(at: 15); XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: 200), 25)
        timer.start(at: 200); XCTAssertEqual(timer.remaining(at: 210), 15)
        timer.start(at: 211); XCTAssertEqual(timer.remaining(at: 212), 13)
        timer.tick(at: 230); XCTAssertFalse(timer.isRunning); XCTAssertEqual(timer.remaining(at: 230), 0)
        timer.reset(); XCTAssertEqual(timer.remaining(at: 231), 30)
    }
    func testVotingOnlyExposesTotalsSupportsOptOutAndErases() throws {
        var vote = LocalVote(options: ["Yes", "No"], voterCount: 4)
        vote.submit(option: 0); vote.submit(option: nil); vote.submit(option: 1); vote.submit(option: 0)
        XCTAssertTrue(vote.isComplete); XCTAssertEqual(vote.totals, [2, 1]); XCTAssertEqual(vote.abstentions, 1)
        vote.submit(option: 1); XCTAssertEqual(vote.totals, [2, 1])
        // Reflection guards against accidentally adding voter IDs or ballot history.
        let fields = Set(Mirror(reflecting: vote).children.compactMap(\.label))
        XCTAssertEqual(fields, ["options", "totals", "submitted", "abstentions", "voterCount"])
        let save = String(data: try JSONEncoder().encode(SavedState()), encoding: .utf8)!
        XCTAssertFalse(save.contains("totals")); XCTAssertFalse(save.contains("ballot"))
        vote.clear(); XCTAssertEqual(vote.totals, [0, 0]); XCTAssertEqual(vote.submitted, 0)
    }
}

#if !SWIFT_PACKAGE
final class AppIntegrationTests: XCTestCase {
    @MainActor
    func testViewModelCompleteSessionResumeModeChangesAndReset() async throws {
        let suite = "UniversityAfterDark.integration.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceStore(defaults: defaults)
        let vm = GameViewModel(store: store)
        vm.updateSettings { $0.sound = false }
        vm.draftPlayers = [Player(name: "Alex"), Player(name: "Emma")]
        vm.ageConfirmed = true; vm.consentConfirmed = true; vm.savePlayers(); vm.start()
        vm.draw(.truth)
        let question = try XCTUnwrap(vm.activeQuestion)
        vm.updateSettings { $0.mode = .randomFate }
        XCTAssertEqual(vm.activeQuestion, question)
        let resumed = GameViewModel(store: store)
        XCTAssertTrue(resumed.canResume); XCTAssertEqual(resumed.activeQuestion, question)
        resumed.finish(); XCTAssertEqual(resumed.session?.statistics.truths, 1)
        resumed.draw(.dare); resumed.finish(skipped: true)
        resumed.end(); XCTAssertFalse(resumed.canResume)
        resumed.resetSession(); XCTAssertNil(resumed.session)
        XCTAssertEqual(resumed.state.players.count, 2)
    }
    @MainActor
    func testCorruptSaveIsNotOverwrittenByLifecyclePersistence() async {
        let suite = "UniversityAfterDark.recovery.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PersistenceStore(defaults: defaults)
        let corrupt = Data("corrupt-save".utf8)
        defaults.set(corrupt, forKey: store.key)
        let vm = GameViewModel(store: store)
        XCTAssertNotNil(vm.error)
        vm.persist()
        XCTAssertEqual(defaults.data(forKey: store.key), corrupt)
        vm.resetSession()
        XCTAssertNoThrow(try store.load())
    }
    @MainActor
    func testViewModelCustomQuestionsCanBeAddedEditedAndDeleted() async throws {
        let suite = "UniversityAfterDark.custom.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = GameViewModel(store: PersistenceStore(defaults: defaults))
        var custom = try XCTUnwrap(vm.bank.first)
        custom.id = "custom_\(UUID())"; custom.isOriginal = false
        vm.addCustom(custom); XCTAssertEqual(vm.state.customQuestions.count, 1)
        custom.text = "An edited question"; vm.addCustom(custom)
        XCTAssertEqual(vm.state.customQuestions.count, 1); XCTAssertEqual(vm.state.customQuestions.first?.text, custom.text)
        vm.removeCustom(custom.id); XCTAssertTrue(vm.state.customQuestions.isEmpty)
    }
}
#endif
