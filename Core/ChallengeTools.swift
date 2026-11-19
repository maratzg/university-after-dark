import Foundation

/// Uses a monotonic clock; pausing captures the remainder and resume makes a new deadline.
struct CountdownState {
    private(set) var duration: TimeInterval = 60
    private var remainder: TimeInterval = 60
    private var deadline: TimeInterval?
    var isRunning: Bool { deadline != nil }
    func remaining(at now: TimeInterval) -> TimeInterval { max(0, deadline.map { $0 - now } ?? remainder) }
    func progress(at now: TimeInterval) -> Double { duration > 0 ? remaining(at: now) / duration : 0 }
    mutating func configure(seconds: Int) { duration = Double(seconds); reset() }
    mutating func start(at now: TimeInterval) {
        guard deadline == nil, remainder > 0 else { return }
        deadline = now + remainder
    }
    mutating func pause(at now: TimeInterval) { remainder = remaining(at: now); deadline = nil }
    mutating func reset() { deadline = nil; remainder = duration }
    mutating func tick(at now: TimeInterval) {
        if isRunning && remaining(at: now) <= 0 { remainder = 0; deadline = nil }
    }
}

/// Intentionally not Codable. No voter-to-choice mapping is ever retained or persisted.
struct LocalVote {
    private(set) var options: [String]
    private(set) var totals: [Int]
    private(set) var submitted = 0
    private(set) var abstentions = 0
    let voterCount: Int
    var isComplete: Bool { submitted >= voterCount }
    init(options: [String], voterCount: Int) {
        self.options = options
        self.totals = Array(repeating: 0, count: options.count)
        self.voterCount = voterCount
    }
    mutating func submit(option: Int?) {
        guard !isComplete else { return }
        if let option, totals.indices.contains(option) { totals[option] += 1 }
        else { abstentions += 1 }
        submitted += 1
    }
    var aggregate: [(label: String, count: Int)] { Array(zip(options, totals)).map { ($0, $1) } }
    mutating func clear() { totals = Array(repeating: 0, count: options.count); submitted = 0; abstentions = 0 }
}
