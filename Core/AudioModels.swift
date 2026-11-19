import Foundation

enum SoundtrackCategory: String, Codable, CaseIterable, Identifiable {
    case afterHours, temptation, secrets, confessions, absoluteChaos, pointOfNoReturn
    var id: String { rawValue }
    var title: String {
        switch self {
        case .afterHours: return "After Hours"
        case .temptation: return "Temptation"
        case .secrets: return "Secrets"
        case .confessions: return "Confessions"
        case .absoluteChaos: return "Absolute Chaos"
        case .pointOfNoReturn: return "Point of No Return"
        }
    }
    var context: String {
        switch self {
        case .afterHours: return "Main menu"
        case .temptation: return "Round 1"
        case .secrets: return "Round 2"
        case .confessions: return "Round 3"
        case .absoluteChaos: return "Round 4"
        case .pointOfNoReturn: return "Nuclear"
        }
    }
    static func round(_ value: Int) -> Self {
        switch value { case 1: return .temptation; case 2: return .secrets; case 3: return .confessions; case 4: return .absoluteChaos; case 5: return .pointOfNoReturn; default: return .afterHours }
    }
}

struct Soundtrack: Codable, Equatable, Identifiable {
    var id: String
    var category: SoundtrackCategory
    var title: String
    var file: String
    var bpm: Double
    static let supportedExtensions = Set(["mp3", "wav", "m4a"])
    var isSupported: Bool {
        let url = URL(fileURLWithPath: file)
        return Self.supportedExtensions.contains(url.pathExtension.lowercased()) && url.lastPathComponent == file
    }
}

enum SoundEffect: String, CaseIterable {
    case truthSelection, dareSelection, questionReveal, roundTransition, nuclearActivation, challengeCompletion
    var file: String { "fx_\(rawValue).wav" }
}

/// Kept separate from the session schema so adding audio never invalidates an existing night.
struct AudioPreferences: Codable, Equatable {
    var musicVolume: Float = 0.32
    var effectsVolume: Float = 0.45
    var musicMuted = false
    var allMuted = false
    var effectsEnabled = true
    var automaticSwitching = true
    var wantsPlayback = true
    var selectedTrackID: String?
    mutating func normalize() {
        musicVolume = musicVolume.isFinite ? min(1, max(0, musicVolume)) : 0.32
        effectsVolume = effectsVolume.isFinite ? min(1, max(0, effectsVolume)) : 0.45
    }
    var audibleMusicVolume: Float { allMuted || musicMuted || !wantsPlayback ? 0 : musicVolume }
    var audibleEffectsVolume: Float { allMuted || !effectsEnabled ? 0 : effectsVolume }
}

struct AudioPreferenceStore {
    static let key = "UniversityAfterDark.audio.v1"
    let defaults: UserDefaults
    func load(legacyEffectsEnabled: Bool = true) -> AudioPreferences {
        var fallback = AudioPreferences(); fallback.effectsEnabled = legacyEffectsEnabled
        guard let data = defaults.data(forKey: Self.key), var value = try? JSONDecoder().decode(AudioPreferences.self, from: data) else { return fallback }
        value.normalize(); return value
    }
    func save(_ preferences: AudioPreferences) {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: Self.key) }
    }
}
