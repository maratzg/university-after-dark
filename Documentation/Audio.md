# Cinematic music and audio

The app includes twelve original, procedural instrumental loops and six new sound effects. Everything plays locally through AVFoundation's AVAudioPlayer. There are no downloads, streaming services, API keys, or licensed commercial recordings. The music is synthesized instrumental composition, not recorded studio music.

## The collection

Each track is a 16-bar arrangement. Sustained voices use extended chord progressions, detuned band-limited synthesizers, and atmospheric noise; arrangements add sub-bass phrases, plucked/FM synth figures, circular stereo echoes, and restrained synthesized drums as appropriate.

| Category | Tracks | Tempo | Character |
| --- | --- | ---: | --- |
| Main menu · After Hours | Velvet After Midnight; Empty Corridors | 72 BPM | Dark ambient pads, sparse plucks, breath and drones |
| Round 1 · Temptation | Velvet Temptation; Low Light | 108 BPM | Deep-house bass, warm four-on-the-floor kick, offbeat hats |
| Round 2 · Secrets | Things Left Unsaid; Behind Closed Doors | 100 BPM | Broken electronic rhythm, dark harmony, restrained percussion |
| Round 3 · Confessions | Glass Confessions; A Quiet Admission | 116 BPM | Minimal techno pulse, syncopated bass, hypnotic synth patterns |
| Round 4 · Absolute Chaos | Beautiful Consequences; Last Good Decision | 92 BPM | Cinematic low end, half-time rhythm, metallic FM texture |
| Nuclear · Point of No Return | Point of No Return; The Room Holds Its Breath | 60 BPM | Industrial ambient, sub drones, sparse metallic resonances |

The collection contains 532.262 seconds of distinct music, about 8 minutes 52 seconds before looping. Loops run approximately 33–64 seconds each. The bundled files are stereo, 32 kHz, 16-bit PCM WAV. Source synthesis is deterministic and uses no samples or third-party compositions.

## Controls

The compact control strip is available during the intro, setup, welcome, game, end screen, and local voting. Pause and master mute are directly accessible; the waveform opens a popover without opening a gameplay-blocking settings sheet. The full panel is also in Settings.

The panel provides the current track/category and state, play/pause, next track, music-only mute, independent music/effect levels, immediate all-audio mute, effects enable/disable, automatic switching, and a manual category picker. Escape closes the popover. **⌘⇧M** toggles all audio mute from anywhere in the app. Master mute reaches both sides of a crossfade and any playing effect immediately.

Automatic switching follows the active game round, including Escalation. Chaos follows the chosen unlocked round rather than changing music for each random card. Menu/setup/end screens use After Hours. Selecting a category manually disables Automatic and holds that soundtrack across navigation. Re-enabling Automatic immediately follows the current context. Next Track advances within the chosen category, and ordinary questions never reload its voice.

Music level defaults to 32%; effects default to 45%. Preferences, music pause, music mute, master mute, automatic/manual selection, and the selected track are saved separately under `UniversityAfterDark.audio.v1`. Existing session saves remain compatible. The previous sound-effects preference is used as the initial effects setting. Track playback position is retained during pause/resume and app inactivity, but is intentionally not saved across process launches.

## Playback and transitions

`MusicManager` owns at most two music voices during a transition and one reusable player for each of the six effects. Audio decoding and AVAudioPlayer preparation happen on worker tasks. Outgoing-player stop/release also runs away from the UI, because stopping a player can wait for hardware.

Ordinary changes use a short equal-power crossfade, approximately 0.85 seconds, with a restrained transition cue. Nuclear activation fades the old music for 0.22 seconds, leaves 0.12 seconds of silence, plays a low impact, then brings up the Nuclear bed. A Nuclear reveal uses the same impact cue for its card and a restrained lighting pulse. Subsequent Nuclear questions briefly duck the existing bed instead of restarting it. Reduce Motion suppresses the light pulse. Muting or pausing never prevents gameplay from advancing.

AVAudioPlayer uses `numberOfLoops = -1` for the PCM loops. Oscillators and modulation are periodic over the buffer; note/drum tails and stereo delays wrap around the loop boundary. The render avoids an end-of-track fade to silence, so loop playback does not insert a gap. Pads and rhythms continue over the seam.

There are separate effects for Truth selection, Dare selection, reveal, round change, Nuclear activation, and completion. Effects are preloaded and reused. The render leaves peak headroom and uses restrained effect levels. A missing catalog/category/file or a decoder/device failure produces a notice in the panel and retains working music where possible; it never prevents a game session.

Music pauses while the app is inactive and resumes only if the user had not paused it. Effects are silenced during inactivity. Closing the window or terminating the app cancels pending work and retires the players.

## Files, regeneration, and replacement

- `Application/MusicManager.swift`: playback, cancellation, fades, cues and lifecycle.
- `Application/MusicControls.swift`: shared controls and synchronized lighting.
- `Core/AudioModels.swift`: categories, catalog types, preferences and migration.
- `Resources/Audio/`: catalog, twelve music WAV files, six effects and render metrics.
- `Tools/make_soundtrack.py`: deterministic synthesis, with NumPy as a developer-only regeneration dependency.
- `Tools/validate_audio.py`: independent measurements of the actual bundled PCM.
- `Documentation/AudioValidation.json`: recorded independent PCM measurements.

The application has no NumPy or Python runtime dependency. Already-rendered audio is bundled in the Xcode project. To regenerate, run `python3 Tools/make_soundtrack.py` in an environment with NumPy, then `python3 Tools/validate_audio.py` and rebuild.

To use other properly licensed local tracks, place them in `Resources/Audio/` and edit `catalog.json`. Each entry has a stable ID, one of the six category raw values, display title, filename and BPM. Filenames may use **MP3, WAV, or M4A** and must be local basenames. AVAudioPlayer handles decoding. Keep at least two tracks per category for meaningful Next behavior. PCM WAV is used for the bundled seamless loops; replacement compressed tracks can have encoder padding and should be checked for gapless boundaries before shipping. Rebuild to bundle changed assets. The Audio directory is copied as a folder, preserving its paths.

## Verification

The Xcode suite has 51 passing cases, including 21 audio-specific tests. Tests cover all six categories, actual AVAudioPlayer decoding of all 18 audio files, independent preferences/mute, compatibility migration, supported extensions, non-restarting round context, next-track cycling, manual/automatic behavior, pause/playhead retention, master mute during a fade, effect levels, inactivity, missing/corrupt assets, stale asynchronous loads, disposal, and synchronized Nuclear reveals with rapid-button protection.

Independent validation checks all twelve actual PCM files: distinct content, exact 16-bar durations, stereo content, bass/body/upper spectral content, consistent RMS near 0.105, peak below 0.71, and boundary deltas below 0.012 full scale. This is objective asset/engine validation; artistic listening preferences and different speakers remain subjective. Live UI checks additionally confirmed Playing status, Next, Pause/Play, master mute, independent volume changes, manual Nuclear selection and automatic return.
