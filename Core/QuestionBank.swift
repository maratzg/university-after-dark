import Foundation

struct BankError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

struct QuestionBank {
    let questions: [Question]
    static func load() throws -> QuestionBank {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "questions", withExtension: "json") else {
            throw BankError(message: "The bundled question bank is missing. Rebuild the app with its Resources phase.")
        }
        let questions = try JSONDecoder().decode([Question].self, from: Data(contentsOf: url))
        try validate(questions, bundled: true)
        return QuestionBank(questions: questions)
    }

    static func validate(_ questions: [Question], bundled: Bool = false) throws {
        guard Set(questions.map(\.id)).count == questions.count else { throw BankError(message: "Duplicate question IDs.") }
        for question in questions {
            guard !question.id.isEmpty, !question.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BankError(message: "A question has empty text or an empty ID.")
            }
            guard (1...5).contains(question.round), question.intensity == Rounds.intensity(question.round),
                  (question.type == .nuclear) == (question.round == 5) else {
                throw BankError(message: "Invalid category or intensity: \(question.id).")
            }
            if question.type == .nuclear && (question.title?.isEmpty ?? true) { throw BankError(message: "Nuclear challenges need a title.") }
            if let seconds = question.timerSeconds, !(1...3600).contains(seconds) { throw BankError(message: "Invalid timer length.") }
        }
        if bundled {
            guard questions.count == 197, questions.filter(\.isOriginal).count == 95,
                  questions.filter({ !$0.isOriginal }).count == 102,
                  !questions.contains(where: \.isCustom) else { throw BankError(message: "The supplied question collection is incomplete.") }
        }
    }
}

/// Persistent shuffle bags plus global history prevent repeats across overlapping mode pools.
struct QuestionRandomizer: Codable, Equatable {
    private(set) var usedIDs: Set<String> = []
    private(set) var bags: [String: [String]] = [:]
    private(set) var lastID: String?

    mutating func draw(from pool: [Question]) -> Question? {
        guard !pool.isEmpty else { return nil }
        let key = pool.map(\.id).sorted().joined(separator: "|")
        let lookup = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var bag = (bags[key] ?? []).filter { lookup[$0] != nil && !usedIDs.contains($0) }
        if bag.isEmpty {
            bag = pool.map(\.id).filter { !usedIDs.contains($0) }.shuffled()
        }
        guard !bag.isEmpty else { bags[key] = []; return nil }
        if bag.last == lastID, bag.count > 1 { bag.swapAt(bag.count - 1, 0) }
        let id = bag.removeLast()
        bags[key] = bag
        usedIDs.insert(id)
        lastID = id
        return lookup[id]
    }

    mutating func reset(pool: [Question]) {
        usedIDs.subtract(pool.map(\.id))
        // Clear overlapping queues; history outside this pool remains intact.
        bags.removeAll()
    }
}

struct PersistenceStore {
    let defaults: UserDefaults
    let key: String
    init(defaults: UserDefaults = .standard, key: String = "UniversityAfterDark.state.v1") {
        self.defaults = defaults
        self.key = key
    }
    func save(_ state: SavedState) throws { defaults.set(try JSONEncoder().encode(state), forKey: key) }
    func load() throws -> SavedState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let state = try JSONDecoder().decode(SavedState.self, from: data)
        guard state.version == 1 else { throw BankError(message: "This save was made with a different version of the app.") }
        if !state.players.isEmpty, let error = PlayerValidation.error(for: state.players) { throw BankError(message: error) }
        try QuestionBank.validate(state.customQuestions)
        guard state.customQuestions.allSatisfy(\.isCustom) else { throw BankError(message: "Invalid custom question IDs in save.") }
        if let session = state.session {
            if let error = PlayerValidation.error(for: session.players) { throw BankError(message: error) }
            let ids = Set(session.players.map(\.id))
            guard ids == Set(session.turnOrder), session.turnOrder.count == ids.count,
                  ids == Set(session.nextCycle), session.nextCycle.count == ids.count,
                  session.turnOrder.indices.contains(session.position),
                  session.turnOrder[session.position] == session.currentPlayerID,
                  (1...4).contains(session.settings.round) else { throw BankError(message: "The saved turn rotation is invalid.") }
        }
        return state
    }
    func reset() { defaults.removeObject(forKey: key) }
}
