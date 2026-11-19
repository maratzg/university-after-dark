import XCTest
#if SWIFT_PACKAGE
@testable import UniversityAfterDarkCore
#else
import AVFoundation
@testable import UniversityAfterDark
#endif

final class AudioPreferencesTests: XCTestCase {
    func testIndependentVolumeClamping() {
        var p = AudioPreferences(); p.musicVolume = -2; p.effectsVolume = 3; p.normalize()
        XCTAssertEqual(p.musicVolume, 0); XCTAssertEqual(p.effectsVolume, 1)
        p.musicVolume = .nan; p.effectsVolume = .infinity; p.normalize()
        XCTAssertEqual(p.musicVolume, 0.32); XCTAssertEqual(p.effectsVolume, 0.45)
    }
    func testPreferencesPersistMutePauseAndManualSelection() {
        let suite = "UAD.audio.prefs.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AudioPreferenceStore(defaults: defaults)
        var p = AudioPreferences(); p.musicVolume = 0.2; p.effectsVolume = 0.7
        p.musicMuted = true; p.allMuted = true; p.wantsPlayback = false; p.automaticSwitching = false; p.selectedTrackID = "menu_02"
        store.save(p); XCTAssertEqual(store.load(), p)
        XCTAssertEqual(p.audibleEffectsVolume, 0); p.allMuted = false
        XCTAssertEqual(p.audibleEffectsVolume, 0.7); XCTAssertEqual(p.audibleMusicVolume, 0)
    }
    func testLegacyEffectMuteAndCorruptPreferencesFallback() {
        let suite = "UAD.audio.legacy.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AudioPreferenceStore(defaults: defaults)
        XCTAssertFalse(store.load(legacyEffectsEnabled: false).effectsEnabled)
        defaults.set(Data("corrupt".utf8), forKey: AudioPreferenceStore.key)
        XCTAssertTrue(store.load(legacyEffectsEnabled: true).effectsEnabled)
    }
    func testRoundMappingAndMP3WAVM4ASupport() {
        XCTAssertEqual((0...5).map(SoundtrackCategory.round), SoundtrackCategory.allCases)
        for ext in ["mp3", "wav", "m4a", "WAV"] {
            XCTAssertTrue(Soundtrack(id: ext, category: .afterHours, title: ext, file: "music.\(ext)", bpm: 72).isSupported)
        }
        for file in ["../private.wav", "file.url"] {
            XCTAssertFalse(Soundtrack(id: file, category: .afterHours, title: file, file: file, bpm: 72).isSupported)
        }
    }
}

#if !SWIFT_PACKAGE
private final class FakeVoice: AudioVoice, @unchecked Sendable {
    private let lock = NSLock()
    let url: URL
    let looping: Bool
    private var level: Float = 0
    private var position: TimeInterval = 0
    private var playing = false
    private var stops = 0
    init(url: URL, looping: Bool) { self.url = url; self.looping = looping }
    var volume: Float { get { lock.withLock { level } } set { lock.withLock { level = newValue } } }
    var currentTime: TimeInterval { get { lock.withLock { position } } set { lock.withLock { position = newValue } } }
    var isPlaying: Bool { lock.withLock { playing } }
    var stopCount: Int { lock.withLock { stops } }
    func play() -> Bool { lock.withLock { playing = true }; return true }
    func pause() { lock.withLock { playing = false } }
    func stop() { lock.withLock { stops += 1; playing = false } }
    func setVolume(_ volume: Float, fadeDuration: TimeInterval) { self.volume = volume }
}
private final class FakeAudioLoader: AudioLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var prepared: [FakeVoice] = []
    var failingFiles: Set<String> = []
    let delay: TimeInterval
    init(delay: TimeInterval = 0) { self.delay = delay }
    var voices: [FakeVoice] { lock.withLock { prepared } }
    var music: [FakeVoice] { voices.filter(\.looping) }
    func load(_ url: URL, looping: Bool) async throws -> any AudioVoice {
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        if failingFiles.contains(url.lastPathComponent) { throw BankError(message: "Invalid audio fixture") }
        let voice = FakeVoice(url: url, looping: looping)
        lock.withLock { prepared.append(voice) }; return voice
    }
}

@MainActor
final class MusicManagerTests: XCTestCase {
    private func fixture(loader: FakeAudioLoader = FakeAudioLoader(), timing: AudioTiming = .instant, missing: Set<String> = []) -> (MusicManager, FakeAudioLoader) {
        let suite = "UAD.audio.engine.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let tracks = SoundtrackCategory.allCases.flatMap { c in
            (1...2).map { Soundtrack(id: "\(c.rawValue)_\($0)", category: c, title: "\(c.title) \($0)", file: "\(c.rawValue)_\($0).wav", bpm: 72) }
        }
        let library = AudioLibrary(tracks: tracks, resolve: { missing.contains($0) ? nil : URL(fileURLWithPath: "/fixtures/\($0)") })
        return (MusicManager(defaults: defaults, library: library, loader: loader, timing: timing), loader)
    }
    private func settle(_ manager: MusicManager) async throws {
        for _ in 0..<300 {
            if !manager.isTransitioning { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Audio transition did not finish")
    }
    func testSameRoundNeverReloadsBetweenQuestions() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .temptation); try await settle(m)
        for _ in 0..<100 { m.follow(.temptation) }; try await settle(m)
        XCTAssertEqual(l.music.count, 1); XCTAssertEqual(m.currentTrack?.category, .temptation)
    }
    func testAutomaticSwitchingAndManualHold() async throws {
        let (m, _) = fixture(); defer { m.shutdown() }
        m.activate(context: .afterHours); try await settle(m)
        m.selectCategory(.confessions); try await settle(m)
        XCTAssertFalse(m.preferences.automaticSwitching)
        m.follow(.absoluteChaos); try await settle(m); XCTAssertEqual(m.currentTrack?.category, .confessions)
        m.updatePreferences { $0.automaticSwitching = true }; try await settle(m)
        XCTAssertEqual(m.currentTrack?.category, .absoluteChaos)
    }
    func testNextTrackCyclesWithinCategory() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .secrets); try await settle(m); let first = m.currentTrack?.id
        m.nextTrack(); try await settle(m); XCTAssertNotEqual(first, m.currentTrack?.id)
        m.follow(.secrets); try await settle(m); XCTAssertEqual(l.music.count, 2)
        m.nextTrack(); try await settle(m); XCTAssertEqual(first, m.currentTrack?.id)
    }
    func testPauseResumeKeepsPositionAndVoice() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .afterHours); try await settle(m)
        let voice = try XCTUnwrap(l.music.first); voice.currentTime = 17.2
        m.togglePlayback(); XCTAssertFalse(voice.isPlaying); XCTAssertFalse(m.preferences.wantsPlayback)
        m.togglePlayback(); XCTAssertTrue(voice.isPlaying)
        XCTAssertEqual(voice.currentTime, 17.2); XCTAssertEqual(l.music.count, 1)
    }
    func testMuteDuringCrossfadeStaysSilent() async throws {
        let (m, l) = fixture(timing: AudioTiming(crossfade: 0.12, nuclearFadeOut: 0.01, nuclearSilence: 0.01, revealDuck: 0.01))
        defer { m.shutdown() }
        m.activate(context: .temptation); try await settle(m); m.nextTrack()
        try await Task.sleep(for: .milliseconds(30)); m.toggleAllMute()
        XCTAssertTrue(l.voices.allSatisfy { $0.volume == 0 })
        try await settle(m); XCTAssertTrue(l.voices.allSatisfy { $0.volume == 0 })
        m.toggleAllMute(); XCTAssertEqual(l.music.last?.volume, m.preferences.musicVolume)
    }
    func testIndependentMusicAndEffectVolumes() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .afterHours); try await settle(m)
        m.updatePreferences { $0.musicVolume = 0.14; $0.effectsVolume = 0.63 }; m.playEffect(.truthSelection)
        XCTAssertEqual(l.music.first?.volume, 0.14)
        let effect = try XCTUnwrap(l.voices.first { $0.url.lastPathComponent == SoundEffect.truthSelection.file })
        XCTAssertEqual(effect.volume, 0.63); XCTAssertTrue(effect.isPlaying)
        m.toggleMusicMute(); XCTAssertEqual(l.music.first?.volume, 0); XCTAssertEqual(effect.volume, 0.63)
        m.updatePreferences { $0.effectsEnabled = false }; XCTAssertFalse(effect.isPlaying)
    }
    func testSuspensionDoesNotOverrideUserPause() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .confessions); try await settle(m)
        let voice = try XCTUnwrap(l.music.first); voice.currentTime = 8
        m.suspend(true); XCTAssertFalse(voice.isPlaying); XCTAssertTrue(m.preferences.wantsPlayback)
        m.suspend(false); XCTAssertTrue(voice.isPlaying); XCTAssertEqual(voice.currentTime, 8)
        m.togglePlayback(); m.suspend(true); m.suspend(false); XCTAssertFalse(voice.isPlaying)
    }
    func testMissingCategoryRetainsWorkingMusic() async throws {
        let (m, l) = fixture(missing: ["secrets_1.wav", "secrets_2.wav"]); defer { m.shutdown() }
        m.activate(context: .temptation); try await settle(m); m.follow(.secrets)
        XCTAssertNotNil(m.notice); XCTAssertEqual(m.currentTrack?.category, .temptation)
        XCTAssertTrue(l.music.first?.isPlaying == true)
    }
    func testCorruptTrackReportsFailureAndRetainsPreviousTrack() async throws {
        let loader = FakeAudioLoader(); loader.failingFiles = ["secrets_1.wav"]
        let (m, _) = fixture(loader: loader); defer { m.shutdown() }
        m.activate(context: .afterHours); try await settle(m); let id = m.currentTrack?.id
        m.follow(.secrets); try await settle(m)
        XCTAssertEqual(m.currentTrack?.id, id); XCTAssertNotNil(m.notice); XCTAssertEqual(m.playbackState, .playing)
    }
    func testNuclearImpactSharesOneRevealCue() async throws {
        let (m, _) = fixture(); defer { m.shutdown() }
        m.activate(context: .temptation); try await settle(m); m.follow(.pointOfNoReturn)
        var reveals = 0
        m.revealNuclear { reveals += 1; XCTAssertEqual(m.nuclearImpact, 1) }
        try await settle(m); XCTAssertEqual(m.currentTrack?.category, .pointOfNoReturn)
        XCTAssertEqual(reveals, 1); XCTAssertEqual(m.nuclearImpact, 1)
    }
    func testNuclearRedrawDoesNotRestartTheTrack() async throws {
        let (m, l) = fixture(); defer { m.shutdown() }
        m.activate(context: .pointOfNoReturn); try await settle(m)
        let count = l.music.count; let cue = m.nuclearImpact; var revealed = false
        m.revealNuclear { revealed = true }
        for _ in 0..<50 { if revealed { break }; await Task.yield() }
        XCTAssertTrue(revealed); XCTAssertEqual(l.music.count, count); XCTAssertEqual(m.nuclearImpact, cue + 1)
    }
    func testRapidChangesAndShutdownDisposeEveryVoice() async throws {
        let (m, l) = fixture(loader: FakeAudioLoader(delay: 0.015))
        m.activate(context: .afterHours); m.nextTrack(); m.follow(.confessions); m.follow(.absoluteChaos)
        try await settle(m); XCTAssertEqual(m.currentTrack?.category, .absoluteChaos); m.shutdown()
        try await Task.sleep(for: .milliseconds(140))
        XCTAssertTrue(l.voices.allSatisfy { !$0.isPlaying && $0.volume == 0 && $0.stopCount > 0 })
        XCTAssertFalse(m.isTransitioning)
    }
    func testEscapeClosesMusicPanelBeforeOtherOverlays() async {
        let (m, _) = fixture(); defer { m.shutdown() }
        let suite = "UAD.audio.escape.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = GameViewModel(store: PersistenceStore(defaults: defaults), music: m)
        vm.voteOpen = true; m.controlsPresented = true
        vm.handleKey("escape")
        XCTAssertFalse(m.controlsPresented); XCTAssertTrue(vm.voteOpen)
        vm.handleKey("escape"); XCTAssertFalse(vm.voteOpen)
    }
    func testDelayedRevealPreservesConcurrentPlayerAndSettingsEdits() async throws {
        let (m, _) = fixture(loader: FakeAudioLoader(delay: 0.02)); defer { m.shutdown() }
        let suite = "UAD.audio.edits.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = GameViewModel(store: PersistenceStore(defaults: defaults), music: m)
        vm.draftPlayers = [Player(name: "Alex"), Player(name: "Emma")]
        vm.ageConfirmed = true; vm.consentConfirmed = true; vm.savePlayers()
        vm.updateSettings { $0.mode = .nuclear }; vm.start(); m.activate(context: vm.soundtrackCategory)
        vm.draw(.nuclear)
        vm.updateSettings { $0.mode = .classic; $0.round = 3 }
        let updated = [Player(name: "Guest A"), Player(name: "Guest B")]
        vm.draftPlayers = updated; vm.savePlayers(inSession: true)
        try await settle(m)
        XCTAssertEqual(vm.session?.settings.mode, .classic)
        XCTAssertEqual(vm.session?.settings.round, 3)
        XCTAssertEqual(vm.session?.players, updated)
        XCTAssertEqual(vm.session?.statistics.drawn, 1)
        XCTAssertEqual(vm.activeQuestion?.type, .nuclear)
    }
    func testRapidNuclearPressesOnlyCommitOneQuestion() async throws {
        let (m, _) = fixture(); defer { m.shutdown() }
        let suite = "UAD.audio.game.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = GameViewModel(store: PersistenceStore(defaults: defaults), music: m)
        vm.draftPlayers = [Player(name: "Alex"), Player(name: "Emma")]
        vm.ageConfirmed = true; vm.consentConfirmed = true; vm.savePlayers()
        vm.updateSettings { $0.mode = .nuclear }; vm.start(); m.activate(context: vm.soundtrackCategory)
        for _ in 0..<20 { vm.draw(.nuclear) }; try await settle(m)
        XCTAssertFalse(vm.nuclearRevealPending); XCTAssertEqual(vm.session?.statistics.drawn, 1)
        XCTAssertEqual(vm.activeQuestion?.type, .nuclear)
    }
}

final class BundledAudioTests: XCTestCase {
    func testEveryTrackAndEffectDecodesWithAVAudioPlayer() throws {
        let library = AudioLibrary.bundled(); XCTAssertNil(library.warning); XCTAssertEqual(library.tracks.count, 12)
        for category in SoundtrackCategory.allCases { XCTAssertEqual(library.tracks.filter { $0.category == category }.count, 2) }
        for track in library.tracks {
            let player = try AVAudioPlayer(contentsOf: XCTUnwrap(library.resolve(track.file)))
            XCTAssertGreaterThan(player.duration, 30); XCTAssertEqual(player.numberOfChannels, 2)
        }
        for effect in SoundEffect.allCases {
            let player = try AVAudioPlayer(contentsOf: XCTUnwrap(library.resolve(effect.file)))
            XCTAssertGreaterThan(player.duration, 0.1); XCTAssertLessThan(player.duration, 2)
        }
    }
    func testGeneratedLoopsHaveHeadroomConsistentLevelsAndCleanSeams() throws {
        struct Metrics: Decodable { var rms: Double; var peak: Double; var seamDelta: Double }
        let url = try XCTUnwrap(AudioLibrary.bundled().resolve("AudioQuality.json"))
        let metrics = try JSONDecoder().decode([Metrics].self, from: Data(contentsOf: url)); XCTAssertEqual(metrics.count, 12)
        for item in metrics {
            XCTAssertEqual(item.rms, 0.105, accuracy: 0.001); XCTAssertLessThan(item.peak, 0.71); XCTAssertLessThan(item.seamDelta, 0.012)
        }
    }
}
#endif
