import AVFoundation
import Combine
import Foundation

protocol AudioVoice: AnyObject, Sendable {
    var volume: Float { get set }
    var currentTime: TimeInterval { get set }
    var isPlaying: Bool { get }
    func play() -> Bool
    func pause()
    func stop()
    func setVolume(_ volume: Float, fadeDuration: TimeInterval)
}

/// Prepared on a worker task, then exclusively owned by MusicManager until retirement.
/// A retired voice is never touched again on the main actor.
final class PlayerVoice: AudioVoice, @unchecked Sendable {
    private let player: AVAudioPlayer
    init(_ player: AVAudioPlayer) { self.player = player }
    var volume: Float { get { player.volume } set { player.volume = newValue } }
    var currentTime: TimeInterval { get { player.currentTime } set { player.currentTime = newValue } }
    var isPlaying: Bool { player.isPlaying }
    func play() -> Bool { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }
    func setVolume(_ volume: Float, fadeDuration: TimeInterval) { player.setVolume(volume, fadeDuration: fadeDuration) }
}

protocol AudioLoading: Sendable {
    func load(_ url: URL, looping: Bool) async throws -> any AudioVoice
}

struct LocalAudioLoader: AudioLoading {
    func load(_ url: URL, looping: Bool) async throws -> any AudioVoice {
        try await Task.detached(priority: .utility) {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = looping ? -1 : 0
            player.volume = 0
            guard player.prepareToPlay() else { throw BankError(message: "Unable to prepare \(url.lastPathComponent).") }
            return PlayerVoice(player) as any AudioVoice
        }.value
    }
}

struct AudioLibrary {
    var tracks: [Soundtrack]
    var resolve: (String) -> URL?
    var warning: String?
    static func bundled(_ bundle: Bundle = .main) -> AudioLibrary {
        let resolver: (String) -> URL? = { file in
            guard URL(fileURLWithPath: file).lastPathComponent == file else { return nil }
            return bundle.url(forResource: file, withExtension: nil, subdirectory: "Audio")
        }
        do {
            guard let url = resolver("catalog.json") else { throw BankError(message: "The local soundtrack catalog is missing.") }
            let tracks = try JSONDecoder().decode([Soundtrack].self, from: Data(contentsOf: url))
            guard !tracks.isEmpty, Set(tracks.map(\.id)).count == tracks.count, tracks.allSatisfy(\.isSupported) else {
                throw BankError(message: "The local soundtrack catalog contains invalid entries.")
            }
            return AudioLibrary(tracks: tracks, resolve: resolver)
        } catch { return AudioLibrary(tracks: [], resolve: resolver, warning: error.localizedDescription) }
    }
}

struct AudioTiming {
    var crossfade: TimeInterval = 0.85
    var nuclearFadeOut: TimeInterval = 0.22
    var nuclearSilence: TimeInterval = 0.12
    var revealDuck: TimeInterval = 0.12
    static let instant = AudioTiming(crossfade: 0, nuclearFadeOut: 0, nuclearSilence: 0, revealDuck: 0)
}

@MainActor
final class MusicManager: ObservableObject {
    enum PlaybackState: String { case paused = "Paused", playing = "Playing", loading = "Loading", unavailable = "Unavailable", suspended = "Paused while away" }
    private struct Slot {
        var track: Soundtrack
        var voice: any AudioVoice
        var gain: Float
    }
    @Published private(set) var preferences: AudioPreferences
    @Published private(set) var currentTrack: Soundtrack?
    @Published private(set) var playbackState: PlaybackState = .paused
    @Published private(set) var isTransitioning = false
    @Published private(set) var notice: String?
    @Published private(set) var nuclearImpact = 0
    @Published private(set) var desiredCategory: SoundtrackCategory = .afterHours
    @Published var controlsPresented = false
    let library: AudioLibrary
    private let preferenceStore: AudioPreferenceStore
    private let loader: any AudioLoading
    private let timing: AudioTiming
    private var active: Slot?
    private var outgoing: Slot?
    private var requestedTrack: Soundtrack?
    private var transitionTask: Task<Void, Never>?
    private var effectPreload: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var delayedEffect: Task<Void, Never>?
    private var effects: [SoundEffect: any AudioVoice] = [:]
    private var lastTracks: [SoundtrackCategory: String] = [:]
    private var generation = 0
    private var revealGeneration = 0
    private var isActivated = false
    private var isSuspended = false
    private var duck: Float = 1
    private var awaitingNuclearImpact = false
    private var pendingReveal: (() -> Void)?

    init(defaults: UserDefaults = .standard, library: AudioLibrary = .bundled(), loader: any AudioLoading = LocalAudioLoader(), timing: AudioTiming = AudioTiming(), legacyEffectsEnabled: Bool = true) {
        self.preferenceStore = AudioPreferenceStore(defaults: defaults)
        self.library = library; self.loader = loader; self.timing = timing
        self.preferences = preferenceStore.load(legacyEffectsEnabled: legacyEffectsEnabled)
        self.notice = library.warning
    }
    var isPlaying: Bool { playbackState == .playing }
    var statusLabel: String {
        if preferences.allMuted { return "All audio muted" }
        if preferences.musicMuted { return "Music muted" }
        return isTransitioning ? "Changing the atmosphere…" : playbackState.rawValue
    }
    var selectedCategory: SoundtrackCategory { requestedTrack?.category ?? currentTrack?.category ?? desiredCategory }
    var canAdvance: Bool { availableTracks(in: selectedCategory).count > 1 }
    private var shouldPlay: Bool { isActivated && !isSuspended && preferences.wantsPlayback }

    func activate(context: SoundtrackCategory) {
        guard !isActivated else { follow(context); return }
        desiredCategory = context
        isActivated = true
        preloadEffects()
        if preferences.automaticSwitching { choose(context) }
        else if let track = library.tracks.first(where: { $0.id == preferences.selectedTrackID }) { request(track, nuclear: false) }
        else { choose(context) }
    }
    func follow(_ context: SoundtrackCategory) {
        let changed = desiredCategory != context
        desiredCategory = context
        guard isActivated, preferences.automaticSwitching, changed else { return }
        choose(context)
    }
    func availableTracks(in category: SoundtrackCategory) -> [Soundtrack] {
        library.tracks.filter { $0.category == category && $0.isSupported && library.resolve($0.file) != nil }
    }
    private func choose(_ category: SoundtrackCategory) {
        let choices = availableTracks(in: category)
        let remembered = lastTracks[category] ?? preferences.selectedTrackID
        guard let track = choices.first(where: { $0.id == remembered }) ?? choices.first else {
            notice = "No playable local tracks for \(category.title). The existing soundtrack is kept."
            if active == nil { playbackState = .unavailable }
            return
        }
        request(track, nuclear: category == .pointOfNoReturn && active?.track.category != category)
    }
    func selectCategory(_ category: SoundtrackCategory) {
        updatePreferences { $0.automaticSwitching = false }
        choose(category)
    }
    func nextTrack() {
        let choices = availableTracks(in: selectedCategory)
        guard !choices.isEmpty else { notice = "No playable local soundtrack is available."; return }
        let id = requestedTrack?.id ?? currentTrack?.id
        let index = choices.firstIndex(where: { $0.id == id }) ?? -1
        request(choices[(index + 1) % choices.count], nuclear: false)
    }
    func togglePlayback() { updatePreferences { $0.wantsPlayback.toggle() } }
    func toggleMusicMute() { updatePreferences { $0.musicMuted.toggle() } }
    func toggleAllMute() { updatePreferences { $0.allMuted.toggle() } }
    func updatePreferences(_ change: (inout AudioPreferences) -> Void) {
        let old = preferences
        change(&preferences); preferences.normalize(); preferenceStore.save(preferences)
        applyVolumes() // Master mute always reaches both sides of a fade immediately.
        if preferences.allMuted || !preferences.effectsEnabled { silenceEffects() }
        if old.wantsPlayback != preferences.wantsPlayback {
            if shouldPlay { resumeVoices() }
            else { active?.voice.pause(); outgoing?.voice.pause(); playbackState = isSuspended ? .suspended : .paused }
        }
        if !old.automaticSwitching && preferences.automaticSwitching && isActivated { choose(desiredCategory) }
    }
    func suspend(_ suspend: Bool) {
        guard isSuspended != suspend else { return }
        isSuspended = suspend
        if suspend {
            active?.voice.pause(); outgoing?.voice.pause(); silenceEffects(); playbackState = .suspended
        } else if shouldPlay { resumeVoices() }
        else { playbackState = .paused }
    }
    private func resumeVoices() {
        if let active {
            if active.voice.play() { playbackState = .playing; applyVolumes() }
            else { playbackState = .unavailable; notice = "The audio device could not start playback. Try Play again." }
        } else if requestedTrack == nil { choose(preferences.automaticSwitching ? desiredCategory : selectedCategory) }
    }
    private func request(_ track: Soundtrack, nuclear: Bool) {
        guard requestedTrack?.id != track.id else { return }
        if active?.track.id == track.id, transitionTask == nil { return }
        guard let url = library.resolve(track.file), track.isSupported else { notice = "Missing or unsupported audio: \(track.file)."; return }
        generation += 1
        let token = generation
        transitionTask?.cancel()
        if let outgoing { retire(outgoing.voice); self.outgoing = nil }
        requestedTrack = track; isTransitioning = true; awaitingNuclearImpact = nuclear
        if active == nil { playbackState = .loading }
        let loader = loader
        transitionTask = Task { [weak self] in
            var prepared: (any AudioVoice)?
            do {
                let voice = try await loader.load(url, looping: true)
                prepared = voice
                guard let self, !Task.isCancelled, self.generation == token else { Self.dispose(voice); return }
                let old = self.active
                if nuclear && self.shouldPlay {
                    let start = old?.gain ?? 0
                    try await self.animate(seconds: self.timing.nuclearFadeOut, token: token) { progress in
                        self.active?.gain = start * (1 - progress); self.applyVolumes()
                    }
                    try await self.sleep(self.timing.nuclearSilence)
                    try Task.checkCancellation()
                    self.fireNuclearImpact()
                }
                if let old { self.outgoing = Slot(track: old.track, voice: old.voice, gain: self.active?.gain ?? old.gain) }
                self.active = Slot(track: track, voice: voice, gain: self.shouldPlay ? 0 : 1)
                prepared = nil // Ownership has moved into the active slot.
                self.currentTrack = track
                self.preferences.selectedTrackID = track.id
                self.lastTracks[track.category] = track.id
                self.preferenceStore.save(self.preferences)
                self.notice = nil
                self.awaitingNuclearImpact = false
                if self.shouldPlay {
                    guard voice.play() else { throw BankError(message: "The audio device could not play \(track.title).") }
                    self.playbackState = .playing
                    if old != nil && !nuclear { self.playEffect(.roundTransition) }
                    let oldGain = self.outgoing?.gain ?? 0
                    try await self.animate(seconds: self.timing.crossfade, token: token) { progress in
                        self.active?.gain = sin(progress * .pi / 2)
                        self.outgoing?.gain = oldGain * cos(progress * .pi / 2)
                        self.applyVolumes()
                    }
                }
                if let outgoing = self.outgoing { self.retire(outgoing.voice); self.outgoing = nil }
                self.active?.gain = 1; self.applyVolumes()
                self.playbackState = self.isSuspended ? .suspended : self.preferences.wantsPlayback ? .playing : .paused
                self.finishTransition(token)
            } catch {
                if let prepared { Self.dispose(prepared) }
                guard let self, self.generation == token else { return }
                if !Task.isCancelled {
                    // Retain the outgoing voice if the device rejects the replacement.
                    if let outgoing = self.outgoing {
                        if let active = self.active { self.retire(active.voice) }
                        self.active = outgoing; self.currentTrack = outgoing.track; self.outgoing = nil
                    }
                    self.active?.gain = 1; self.applyVolumes()
                    self.notice = "Soundtrack unavailable: \(error.localizedDescription)"
                    self.playbackState = self.active == nil || (self.shouldPlay && self.active?.voice.isPlaying != true) ? .unavailable : self.shouldPlay ? .playing : .paused
                }
                self.finishTransition(token)
            }
        }
    }
    private func finishTransition(_ token: Int) {
        guard generation == token else { return }
        isTransitioning = false; requestedTrack = nil; transitionTask = nil; awaitingNuclearImpact = false
        if let action = pendingReveal { pendingReveal = nil; action() }
    }
    private func applyVolumes() {
        let base = preferences.audibleMusicVolume * duck
        active?.voice.setVolume(base * (active?.gain ?? 0), fadeDuration: 0)
        outgoing?.voice.setVolume(base * (outgoing?.gain ?? 0), fadeDuration: 0)
        for voice in effects.values { voice.volume = preferences.audibleEffectsVolume }
    }
    private func animate(seconds: TimeInterval, token: Int? = nil, update: (Float) -> Void) async throws {
        let steps = max(1, Int(seconds / 0.025))
        for step in 1...steps {
            try Task.checkCancellation()
            if let token, token != generation { throw CancellationError() }
            if seconds > 0 { try await sleep(seconds / Double(steps)) }
            update(Float(step) / Float(steps))
        }
    }
    private func sleep(_ seconds: TimeInterval) async throws {
        if seconds > 0 { try await Task.sleep(for: .seconds(seconds)) }
    }
    private func preloadEffects() {
        guard effectPreload == nil else { return }
        effectPreload = Task { [weak self] in
            guard let self else { return }
            for effect in SoundEffect.allCases {
                guard !Task.isCancelled, self.isActivated else { return }
                guard let url = self.library.resolve(effect.file) else { continue }
                if let voice = try? await self.loader.load(url, looping: false) {
                    guard !Task.isCancelled, self.isActivated else { Self.dispose(voice); return }
                    self.effects[effect] = voice
                    voice.volume = self.preferences.audibleEffectsVolume
                }
            }
        }
    }
    func playEffect(_ effect: SoundEffect) {
        guard isActivated, !isSuspended, preferences.audibleEffectsVolume > 0,
              let voice = effects[effect] else { return }
        voice.currentTime = 0; voice.volume = preferences.audibleEffectsVolume
        _ = voice.play()
    }
    func selection(_ type: QuestionType) {
        playEffect(type == .truth ? .truthSelection : .dareSelection)
        delayedEffect?.cancel()
        delayedEffect = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }
            self?.playEffect(.questionReveal)
        }
    }
    /// Reuses an activation's impact if still pending; otherwise ducks without restarting music.
    func revealNuclear(_ reveal: @escaping () -> Void) {
        cancelReveal()
        if awaitingNuclearImpact { pendingReveal = reveal; return }
        let token = revealGeneration
        revealTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.animate(seconds: self.timing.revealDuck) { self.duck = 1 - $0; self.applyVolumes() }
                try await self.sleep(self.timing.nuclearSilence)
                self.fireNuclearImpact(); reveal()
                try await self.animate(seconds: self.timing.crossfade * 0.65) { self.duck = $0; self.applyVolumes() }
            } catch { }
            guard token == self.revealGeneration else { return }
            self.duck = 1; self.applyVolumes()
        }
    }
    private func fireNuclearImpact() {
        awaitingNuclearImpact = false
        playEffect(.nuclearActivation); nuclearImpact += 1
        if let action = pendingReveal { pendingReveal = nil; action() }
    }
    func cancelReveal() { revealGeneration += 1; revealTask?.cancel(); revealTask = nil; pendingReveal = nil; duck = 1; applyVolumes() }
    private func silenceEffects() {
        delayedEffect?.cancel()
        for voice in effects.values { voice.volume = 0; voice.pause(); voice.currentTime = 0 }
    }
    private func retire(_ voice: any AudioVoice) { Self.dispose(voice) }
    private nonisolated static func dispose(_ voice: any AudioVoice) {
        // AVAudioPlayer.stop() can wait for hardware; keep that work away from SwiftUI.
        voice.volume = 0; voice.pause()
        Task.detached(priority: .utility) { voice.stop() }
    }
    func shutdown() {
        generation += 1; isActivated = false
        transitionTask?.cancel(); transitionTask = nil
        effectPreload?.cancel(); effectPreload = nil
        delayedEffect?.cancel(); cancelReveal()
        if let active { retire(active.voice) }; if let outgoing { retire(outgoing.voice) }
        for voice in effects.values { retire(voice) }
        active = nil; outgoing = nil; effects.removeAll(); requestedTrack = nil
        currentTrack = nil; controlsPresented = false; isTransitioning = false; awaitingNuclearImpact = false; playbackState = .paused
    }
}
