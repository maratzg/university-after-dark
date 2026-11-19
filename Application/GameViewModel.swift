import SwiftUI
import AppKit

@MainActor
final class GameViewModel: ObservableObject {
    enum Screen { case intro, welcome, players, configuration, game, end }
    enum Modal: String, Identifiable { case rules, settings, statistics, players, custom
        var id: String { rawValue }
    }
    @Published var screen: Screen = .intro
    @Published var modal: Modal?
    @Published private(set) var state = SavedState()
    @Published var draftPlayers: [Player] = []
    @Published var ageConfirmed = false
    @Published var consentConfirmed = false
    @Published var error: String?
    @Published var exhaustion = false
    @Published var pendingType: QuestionType = .truth
    @Published var replacingPool = false
    @Published var confirmReset = false
    @Published var confirmEnd = false
    @Published var timer = CountdownState()
    @Published var vote: LocalVote?
    @Published var votePrivacyCover = true
    @Published var voteReveal = false
    @Published var voteCategory = 0
    @Published var voteOptionsText = ""
    @Published var voteSetup = false
    @Published var voteOpen = false
    let bank: [Question]
    private let store: PersistenceStore
    let music: MusicManager
    @Published private(set) var nuclearRevealPending = false
    private var recoveryNeeded = false

    init(store: PersistenceStore = PersistenceStore(), music: MusicManager? = nil) {
        self.store = store
        let restored = Result { try store.load() }
        let legacySound = (try? restored.get())?.settings.sound ?? true
        self.music = music ?? MusicManager(defaults: store.defaults, legacyEffectsEnabled: legacySound)
        do { bank = try QuestionBank.load().questions }
        catch { bank = []; self.error = error.localizedDescription }
        do {
            if let saved = try restored.get() { state = saved }
        } catch {
            recoveryNeeded = true
            self.error = "Your saved session could not be loaded: \(error.localizedDescription) The saved data has been kept. Start a new night to replace it."
        }
        draftPlayers = state.players.isEmpty ? [Player(name: ""), Player(name: "")] : state.players
    }

    var soundtrackCategory: SoundtrackCategory {
        screen == .game ? .round(session?.effectiveRound ?? settings.round) : .afterHours
    }
    var session: GameSession? { state.session }
    var settings: GameSettings { state.settings }
    var allQuestions: [Question] { bank + (settings.customEnabled ? state.customQuestions : []) }
    var canResume: Bool { session != nil && session?.isEnded == false }
    var activeQuestion: Question? { session?.currentQuestion }
    var reducedMotion: Bool { settings.reducedMotion || settings.animationIntensity == 0 || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var transition: Animation? { reducedMotion || settings.animationIntensity == 0 ? nil : .easeInOut(duration: 0.28 + settings.animationIntensity * 0.15) }

    func persist() {
        guard !recoveryNeeded else { return }
        do { try store.save(state) }
        catch { self.error = "Could not save this session: \(error.localizedDescription)" }
    }
    func enter() { withAnimation(transition) { screen = .welcome } }
    func beginSetup() {
        ageConfirmed = false; consentConfirmed = false
        draftPlayers = state.players.isEmpty ? [Player(name: ""), Player(name: "")] : state.players
        withAnimation(transition) { screen = .players }
    }
    func savePlayers(inSession: Bool = false) {
        if let message = PlayerValidation.error(for: draftPlayers) { error = message; return }
        let cleaned = draftPlayers.map { player -> Player in
            var player = player; player.name = player.name.trimmingCharacters(in: .whitespacesAndNewlines); return player
        }
        state.players = cleaned
        draftPlayers = cleaned
        if inSession {
            state.session?.replacePlayers(cleaned)
            clearPrivateVote(); modal = nil
        } else { withAnimation(transition) { screen = .configuration } }
        persist()
    }
    func start() {
        guard ageConfirmed, consentConfirmed, !bank.isEmpty, PlayerValidation.error(for: state.players) == nil else { return }
        recoveryNeeded = false
        state.session = GameSession(players: state.players, settings: settings)
        music.cancelReveal(); nuclearRevealPending = false
        clearChallengeTools(); screen = .game; persist()
    }
    func resume() {
        guard canResume else { return }
        ageConfirmed = false; consentConfirmed = false
        modal = .rules
    }
    func confirmResume() {
        guard ageConfirmed, consentConfirmed, canResume else { return }
        modal = nil; screen = .game
        configureTimer(); clearPrivateVote()
    }
    func updateSettings(_ change: (inout GameSettings) -> Void) {
        let oldOrder = settings.order
        let oldSound = settings.sound
        change(&state.settings)
        state.settings.round = min(4, max(1, state.settings.round))
        state.session?.settings = state.settings
        if oldOrder != settings.order { state.session?.restartRotation() }
        if oldSound != settings.sound { music.updatePreferences { $0.effectsEnabled = settings.sound } }
        persist()
    }
    func draw(_ type: QuestionType, replacing: Bool = false) {
        guard var session, !session.isEnded, !nuclearRevealPending, replacing || session.currentQuestion == nil else { return }
        pendingType = type; replacingPool = replacing
        if session.draw(type: type, bank: allQuestions, replacing: replacing) == nil {
            exhaustion = true; return
        }
        let commit = { [weak self] in
            guard let self, var latest = self.state.session, latest.id == session.id, !latest.isEnded else { return }
            // A cue may finish after a settings/player edit. Commit only the draw,
            // preserving the latest roster, rotation, preferences and other statistics.
            latest.randomizer = session.randomizer
            latest.currentQuestion = session.currentQuestion
            latest.nuclearStarted = false
            latest.statistics.drawn += 1
            withAnimation(self.transition) { self.state.session = latest; self.nuclearRevealPending = false }
            self.clearChallengeTools(); self.configureTimer(); self.persist()
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        if type == .nuclear {
            nuclearRevealPending = true
            music.revealNuclear(commit)
        } else {
            music.selection(type)
            commit()
        }
    }
    func drawFate() {
        guard let session, session.currentQuestion == nil else { return }
        draw(settings.mode == .nuclear ? .nuclear : (Bool.random() ? .truth : .dare))
    }
    func newQuestion() { if let question = activeQuestion { draw(question.type, replacing: true) } }
    func finish(skipped: Bool = false) {
        guard activeQuestion != nil, !nuclearRevealPending else { return }
        withAnimation(transition) { state.session?.finishQuestion(skipped: skipped) }
        clearChallengeTools(); persist()
        if !skipped { music.playEffect(.challengeCompletion) }
    }
    func skipPlayer() {
        guard !nuclearRevealPending else { return }
        guard activeQuestion == nil else { finish(skipped: true); return }
        state.session?.advance(); state.session?.statistics.turns += 1; persist()
    }
    func selectPlayer(_ id: UUID) { guard !nuclearRevealPending, activeQuestion == nil else { return }; state.session?.selectPlayer(id); persist() }
    func restartRotation() { state.session?.restartRotation(); persist() }
    func resetPool() {
        guard var session else { return }
        let pool = session.pool(type: pendingType, bank: allQuestions, replacing: replacingPool)
        session.randomizer.reset(pool: pool); state.session = session; exhaustion = false
        draw(pendingType, replacing: replacingPool)
    }
    func openPlayers() {
        draftPlayers = session?.players ?? state.players
        timer.pause(at: ProcessInfo.processInfo.systemUptime); modal = .players
    }
    func end() {
        music.cancelReveal(); nuclearRevealPending = false
        state.session?.isEnded = true; clearChallengeTools(); screen = .end; persist()
    }
    func resetSession() {
        music.cancelReveal(); nuclearRevealPending = false
        recoveryNeeded = false
        state.session = nil; clearChallengeTools(); screen = .welcome; modal = nil; persist()
    }
    func addCustom(_ question: Question) {
        do {
            guard question.isCustom, !bank.contains(where: { $0.id == question.id }) else { throw BankError(message: "Custom questions need a unique custom ID.") }
            var custom = state.customQuestions.filter { $0.id != question.id }; custom.append(question)
            try QuestionBank.validate(custom); state.customQuestions = custom; persist()
        } catch { self.error = error.localizedDescription }
    }
    func removeCustom(_ id: String) { state.customQuestions.removeAll { $0.id == id }; persist() }
    func configureTimer() { timer.configure(seconds: activeQuestion?.timerSeconds ?? 60) }
    func clearPrivateVote() { vote?.clear(); vote = nil; votePrivacyCover = true; voteReveal = false; voteOpen = false; voteSetup = false; voteCategory = 0; voteOptionsText = "" }
    func clearChallengeTools() { timer.reset(); clearPrivateVote() }
    func startNuclear() { state.session?.nuclearStarted = true; persist() }
    var verdictCategories: [String] { ["Most likely to accidentally start a university scandal", "Most likely to fall in love with someone in this room", "Most likely to have a secret relationship nobody knows about"] }
    var voteTitle: String { activeQuestion?.voting == .verdict ? verdictCategories[min(2, voteCategory)] : "A private moment. A shared result." }
    func beginVoting() {
        guard let kind = activeQuestion?.voting, let session else { return }
        if kind == .options && !voteSetup { voteOpen = true; voteSetup = true; return }
        let options: [String]
        switch kind {
        case .yesNo: options = ["Yes", "No"]
        case .players, .verdict: options = session.players.map(\.name)
        case .options: options = voteOptionsText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        guard options.count >= 2, options.count <= 20, Set(options).count == options.count else { error = "Enter 2–20 distinct options, one per line."; return }
        vote = LocalVote(options: options, voterCount: session.players.count)
        voteSetup = false; voteOpen = true; votePrivacyCover = true; voteReveal = false
    }
    func submitVote(_ index: Int?) {
        vote?.submit(option: index); votePrivacyCover = true
    }
    func nextVoteCategory() { vote?.clear(); vote = nil; voteCategory += 1; beginVoting() }
    func togglePresentation() {
        updateSettings { $0.presentation.toggle() }
        if let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) != settings.presentation { window.toggleFullScreen(nil) }
    }
    func stopAudio() { nuclearRevealPending = false; music.shutdown() }
    func handleKey(_ key: String) {
        if key == "escape" {
            if music.controlsPresented { music.controlsPresented = false }
            else if voteOpen { clearPrivateVote() }
            else if modal != nil { modal = nil }
            else if screen == .intro { enter() }
            else if activeQuestion != nil { timer.pause(at: ProcessInfo.processInfo.systemUptime); modal = .settings }
            else if screen == .game { modal = .settings }
            else if screen == .configuration { screen = .players }
            else if screen == .players { screen = .welcome }
            return
        }
        guard modal == nil, !voteOpen, !exhaustion, !confirmEnd, !confirmReset, !nuclearRevealPending else { return }
        if key == "f" { NSApp.keyWindow?.toggleFullScreen(nil); return }
        if screen == .intro, key == " " { enter(); return }
        guard screen == .game else { return }
        switch key {
        case "t" where activeQuestion == nil && settings.mode != .nuclear: draw(.truth)
        case "d" where activeQuestion == nil && settings.mode != .nuclear: draw(.dare)
        case "s": skipPlayer()
        case "n": newQuestion()
        case " ":
            if let question = activeQuestion {
                if question.type == .nuclear && session?.nuclearStarted == false { startNuclear() }
                else { finish() }
            } else { drawFate() }
        default: break
        }
    }
}
