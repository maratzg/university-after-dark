import Foundation

struct Player: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case truth, dare, nuclear
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var symbol: String { self == .truth ? "questionmark" : self == .dare ? "flame" : "sparkle" }
}

enum VotingKind: String, Codable { case players, yesNo, verdict, options }

struct Question: Codable, Identifiable, Equatable {
    var id: String
    var type: QuestionType
    var round: Int
    var intensity: Int
    var title: String?
    var text: String
    var isOriginal: Bool
    var requiresOtherPlayers: Bool
    var timerSeconds: Int?
    var voting: VotingKind?
    var isCustom: Bool { id.hasPrefix("custom_") }
}

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case classic, randomFate, escalation, absoluteChaos, nuclear
    var id: String { rawValue }
    var label: String {
        switch self {
        case .classic: return "Classic"
        case .randomFate: return "Random Fate"
        case .escalation: return "Escalation"
        case .absoluteChaos: return "Absolute Chaos"
        case .nuclear: return "Nuclear"
        }
    }
    var numeral: String { ["I", "II", "III", "IV", "V"][Self.allCases.firstIndex(of: self)!] }
    var summary: String {
        switch self {
        case .classic: return "A choice. A confession. A consequence."
        case .randomFate: return "Surrender the choice. Let the night decide."
        case .escalation: return "Every trip around the room turns up the heat."
        case .absoluteChaos: return "Every unlocked level. No predictable endings."
        case .nuclear: return "The whole room enters the conversation."
        }
    }
}

enum PlayerOrder: String, Codable, CaseIterable { case sequential, shuffled }

struct GameSettings: Codable, Equatable {
    var mode: GameMode = .classic
    var round = 1
    var animationIntensity = 0.7
    var sound = true
    var reducedMotion = false
    var order: PlayerOrder = .sequential
    var presentation = false
    var keyboardHints = true
    var customEnabled = true
}

enum Rounds {
    static let names = ["The social damage begins", "Secrets that should have stayed secret", "The room gets uncomfortably quiet", "Absolute chaos", "Nuclear"]
    static let intensities = [6, 8, 9, 10, 10]
    static func name(_ round: Int) -> String { names[max(0, min(4, round - 1))] }
    static func intensity(_ round: Int) -> Int { intensities[max(0, min(4, round - 1))] }
}

struct SessionStatistics: Codable, Equatable {
    var drawn = 0
    var truths = 0
    var dares = 0
    var skipped = 0
    var nuclear = 0
    var turns = 0
}

struct GameSession: Codable, Equatable {
    var id = UUID()
    var startedAt = Date()
    var players: [Player]
    var currentPlayerID: UUID?
    var settings: GameSettings
    var statistics = SessionStatistics()
    var randomizer = QuestionRandomizer()
    var currentQuestion: Question?
    var nuclearStarted = false
    var isEnded = false
    // A future randomized cycle is saved so the next-player preview stays accurate.
    var nextCycle: [UUID] = []
    var turnOrder: [UUID] = []
    var position = 0

    init(players: [Player], settings: GameSettings) {
        self.players = players
        self.settings = settings
        turnOrder = players.map(\.id)
        if settings.order == .shuffled { turnOrder.shuffle() }
        currentPlayerID = turnOrder.first
        prepareNextCycle()
    }

    var currentPlayer: Player? { players.first { $0.id == currentPlayerID } }
    var nextPlayer: Player? {
        let id = position + 1 < turnOrder.count ? turnOrder[position + 1] : nextCycle.first
        return players.first { $0.id == id }
    }
    var effectiveRound: Int {
        if settings.mode == .nuclear { return 5 }
        if settings.mode == .escalation {
            return min(4, settings.round + statistics.turns / max(1, players.count))
        }
        return min(4, max(1, settings.round))
    }

    mutating func prepareNextCycle() {
        nextCycle = players.map(\.id)
        if settings.order == .shuffled {
            nextCycle.shuffle()
            if nextCycle.first == turnOrder.last, nextCycle.count > 1 { nextCycle.swapAt(0, 1) }
        }
    }

    mutating func advance() {
        guard !turnOrder.isEmpty else { currentPlayerID = nil; return }
        position += 1
        if position >= turnOrder.count {
            turnOrder = nextCycle
            position = 0
            prepareNextCycle()
        }
        currentPlayerID = turnOrder.indices.contains(position) ? turnOrder[position] : turnOrder.first
    }

    mutating func selectPlayer(_ id: UUID) {
        guard let index = turnOrder.firstIndex(of: id) else { return }
        position = index
        currentPlayerID = id
    }

    mutating func restartRotation() {
        turnOrder = players.map(\.id)
        if settings.order == .shuffled { turnOrder.shuffle() }
        position = 0
        currentPlayerID = turnOrder.first
        prepareNextCycle()
    }

    mutating func replacePlayers(_ replacement: [Player]) {
        let oldCurrent = currentPlayerID
        let oldNext = nextPlayer?.id
        players = replacement
        let ids = Set(replacement.map(\.id))
        if settings.order == .sequential {
            turnOrder = replacement.map(\.id)
        } else {
            turnOrder = turnOrder.filter { ids.contains($0) }
            turnOrder.append(contentsOf: replacement.map(\.id).filter { !turnOrder.contains($0) }.shuffled())
        }
        currentPlayerID = [oldCurrent, oldNext, turnOrder.first].compactMap { $0 }.first { ids.contains($0) }
        position = turnOrder.firstIndex(where: { $0 == currentPlayerID }) ?? 0
        prepareNextCycle()
    }
}

enum PlayerValidation {
    static func error(for players: [Player]) -> String? {
        guard (2...20).contains(players.count) else { return "The night needs 2–20 players." }
        let names = players.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ !$0.isEmpty }) else { return "Every player needs a name." }
        guard names.allSatisfy({ $0.count <= 40 }) else { return "Keep player names within 40 characters." }
        let normalized = names.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        guard Set(normalized).count == names.count else { return "Give each player a distinct name." }
        guard Set(players.map(\.id)).count == players.count else { return "Player identifiers must be unique." }
        return nil
    }
}

struct SavedState: Codable {
    var version = 1
    var players: [Player] = []
    var settings = GameSettings()
    var session: GameSession?
    var customQuestions: [Question] = []
}

extension GameSession {
    func pool(type: QuestionType, bank: [Question], replacing: Bool = false) -> [Question] {
        if replacing, let currentQuestion {
            return bank.filter { $0.type == currentQuestion.type && $0.intensity == currentQuestion.intensity }
        }
        return bank.filter { question in
            guard question.type == type else { return false }
            if type == .nuclear { return true }
            if settings.mode == .absoluteChaos { return question.round <= settings.round }
            return question.round == effectiveRound
        }
    }
    @discardableResult
    mutating func draw(type: QuestionType, bank: [Question], replacing: Bool = false) -> Question? {
        guard !isEnded, players.count >= 2, replacing || currentQuestion == nil else { return nil }
        let available = pool(type: type, bank: bank, replacing: replacing)
        guard let question = randomizer.draw(from: available) else { return nil }
        currentQuestion = question
        nuclearStarted = false
        statistics.drawn += 1
        return question
    }
    mutating func finishQuestion(skipped: Bool) {
        guard let question = currentQuestion, !isEnded else { return }
        if skipped { statistics.skipped += 1 }
        else {
            switch question.type {
            case .truth: statistics.truths += 1
            case .dare: statistics.dares += 1
            case .nuclear: statistics.nuclear += 1
            }
        }
        statistics.turns += 1
        currentQuestion = nil
        nuclearStarted = false
        advance()
    }
}
