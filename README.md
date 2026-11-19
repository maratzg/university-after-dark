# University After Dark

“Some questions should never be asked.”

An open-source, offline party game for adults, built with Swift and SwiftUI for macOS 15+. Includes 197 locally bundled challenges, five game modes, and an original cinematic soundtrack.

**18+ only. Participation is voluntary; every question and challenge can be skipped without penalty.**

## Run in Xcode

1. Open `UniversityAfterDark.xcodeproj` in this directory.
2. Select the shared **UniversityAfterDark** scheme and **My Mac** destination.
3. Press **⌘R**. Local ad hoc signing is configured; no developer account or paid membership is needed.

The project uses only Apple frameworks. There are no packages to fetch, accounts, API keys, services, or subscriptions. Xcode 16 or newer is recommended.

Build products are generated locally and are not committed. In Xcode, use **Product → Show Build Folder in Finder** to locate the app after building.

## Build and test from Terminal

From this directory:

```sh
xcodebuild -project UniversityAfterDark.xcodeproj \
  -scheme UniversityAfterDark -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build

xcodebuild -project UniversityAfterDark.xcodeproj \
  -scheme UniversityAfterDark -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData test

python3 Tools/import_questions.py --check
```

If `xcode-select` points to Command Line Tools, prefix these commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. This does not change the system setting.

The core can also be tested with `swift test`. Swift Package Manager builds only the game logic and its bundled JSON. Xcode additionally runs the application integration tests.

## Playing

Confirm that all players are adults and freely agree to play, enter 2–20 distinct names, select a mode, and set the intensity. Every prompt and every part of a dare can be skipped without penalty.

- **Classic:** choose Truth or Dare at the selected intensity.
- **Random Fate:** the app chooses the type; click the card or press Space.
- **Escalation:** the starting intensity rises one level after each player-count of turns, capped at round 4. Nuclear remains a separate group mode.
- **Absolute Chaos:** mix all individual rounds up to the selected unlocked level.
- **Nuclear:** 18 group challenges, with an explicit Start step, optional timers, and optional local ballots where applicable.

Mode changes take effect for the next draw and retain the active challenge, statistics, and question history. **New Question** retains the current type and intensity, including in Chaos. Every draw uses a persistent shuffle bag and shared used-ID history across overlapping pools. Pool exhaustion offers a scoped reset, intensity/mode settings, or return. Resetting avoids an immediate repeat when alternatives exist.

Players can be edited, moved, shuffled, or removed during a session. Select a player in the sidebar between prompts for a manual turn. Settings can restart the rotation or shuffle every cycle. The next-player preview matches the saved rotation, including across shuffled cycles.

## Presentation and shortcuts

The expand icon enters presentation mode and native fullscreen. It uses larger text and hides the sidebar. Move the window to a connected display first to use a television or external monitor. The game uses one shared window; it does not expose a second private host window.

| Key | Action |
| --- | --- |
| T / D | Choose Truth / Dare between challenges |
| Space | Draw, start a Nuclear challenge, or complete the active prompt |
| S | Skip the prompt or current player's turn |
| N | Draw a different prompt of the same type and intensity |
| Escape | Close a voting overlay or sheet; open settings from a game |
| F | Toggle native fullscreen |
| ⌘⇧P | Toggle presentation mode |
| ⌘, | Settings |
| ⌘⇧M | Immediately mute / unmute all audio |

Single-letter shortcuts are disabled during text entry and key-repeat events are ignored. For Classic, Space draws a random type; T and D select explicitly. Fullscreen and presentation layout are separately controllable. Questions wrap and scroll when necessary, with action controls remaining visible.

## Privacy and consent

No personal answers, conversations, or recordings are stored. The sandboxed app has no network entitlements or network code. Names, settings, custom prompts, active challenge, used IDs, shuffle queues, turn order, and statistics are stored using Codable in UserDefaults under `com.local.UniversityAfterDark`.

This repository contains source code and bundled game resources only. Player names, custom prompts entered during play, saved games, app preferences, caches, logs, and local Xcode state are not part of the repository. A new installation starts with an empty player list. Local data is not shared with GitHub or other players.

Votes remain in memory only. Each ballot is separated by a handoff screen; no voter identity or individual ballot history is retained. Every voter can pass. Totals are shown only after an explicit agreement step and are erased on close, completion, skip, redraw, session reset, or exit. Small groups and a shared screen can make choices inferable: the interface explicitly states that anonymity is limited. Final Verdict handles its three categories one at a time, erasing the previous totals before the next category. Free-text paper challenges remain voluntary paper activities; the app does not collect confessions. Story/plan voting uses temporary agreed labels.

Age/consent confirmations are per start/resume and do not request birthdays. Reduce Motion is honored from both app settings and macOS. Music and effects have independent volume controls, a direct master mute, and persistent preferences. The bundled soundtrack contains twelve original layered instrumental loops across all six categories, plus six synthesized effects. See `Documentation/Audio.md` for controls, transitions, asset replacement, and validation.

Timers are optional and support start, pause, resume, reset, and 30/60/120-second presets. They use monotonic elapsed time and pause when a sheet opens or the app becomes inactive. Timers and votes are intentionally ephemeral: resuming an app session restores the question but resets its timer and ballots.

## Project structure

```text
UniversityAfterDark.xcodeproj/    Native app, hosted XCTest target, shared scheme
Application/                    SwiftUI screens, coordinator, MusicManager, audio controls
Core/                           Codable models, rotation, shuffle bags, storage, timer, ballots, audio preferences
Resources/                      questions.json, app icon, legacy effects
Resources/Audio/                12 original loops, 6 effects, soundtrack catalog
Tests/                          Question-bank, mechanics, persistence, privacy, integration tests
Documentation/SourceQuestionBank.txt  Supplied question bank retained for audit
Documentation/Validation.md     Build, test, and visual verification report
Tools/                          Deterministic import, project and asset generation
Package.swift                   Independent core test harness
Info.plist                      macOS app metadata, deployment target 15.0
```

## Question bank

The final count in the brief supersedes its earlier estimates. The JSON has **197** stable unique IDs, **95 original** and **102 additional**, with original/additional flags and assigned categories preserved.

| Round | Original truths | Original dares | Additional truths | Additional dares |
| --- | ---: | ---: | ---: | ---: |
| 1 · 6/10 | 10 | 8 | 10 | 10 |
| 2 · 8/10 | 15 | 8 | 12 | 10 |
| 3 · 9/10 | 15 | 8 | 15 | 10 |
| 4 · 10/10 | 15 | 8 | 15 | 10 |
| Nuclear | 8 group challenges | — | 10 group challenges | — |

`Tools/import_questions.py --check` reparses the retained source and compares every field, title, and question body to the bundled JSON. The runtime rejects missing/invalid banks. Display typography collapses blank paragraph separators to single line breaks; no words are changed. The counter uses the actual enabled deck size, including custom prompts, and separates total draws from distinct seen IDs.

Custom prompts support all three categories, intensity, title, other-player consent hints, optional timers, editing, deletion, and a global inclusion switch. Their `custom_UUID` namespace cannot collide with the bundled IDs. Deleting a custom prompt leaves any already drawn copy in the session until its turn ends.

## Music and audio

The waveform in the header opens the soundtrack panel without interrupting gameplay. Music follows rounds automatically and does not restart for ordinary questions. The panel includes Next, Play/Pause, music-only mute, independent Music/Effects levels, master mute, and an Automatic toggle. Selecting a category manually holds it until Automatic is re-enabled. Music pauses while the app is inactive. Nuclear reveals share a timed impact and lighting cue; Reduce Motion suppresses that pulse. All preferences are saved separately, keeping existing nights compatible.

Read `Documentation/Audio.md` for the complete soundtrack list, engine behavior, asset formats, and regeneration instructions.

## Verification and practical limits

See `Documentation/Validation.md` for the recorded build and test results. The app was built and launched on this Mac; all hosted XCTest tests passed. Native fullscreen, resized windows, keyboard gameplay, group voting, and the setup flow were also checked in the running UI.

Local builds use ad hoc signing and do not require a paid developer membership. Prebuilt distribution and notarization are separate from building the source. Physical external-display and macOS 15 runtime checks have not been completed. Shared-screen voting has limited anonymity. Very long custom questions scroll instead of shrinking or truncating.

## License

Released under the [MIT License](LICENSE), including the original procedural soundtrack and generated effects bundled with this project. Audio generation and validation scripts are included in `Tools/`.
