# Validation report

The app's deployment target is macOS 15.0. The initial native app and audio validation used Xcode 26.5 (17F42) and its macOS 26.5 SDK. Build products, machine-specific logs and test-result bundles are generated locally and are not checked into the repository.

The source was rechecked on 19 November 2026: all 51 hosted Xcode tests passed, both project property lists validated, and the importer confirmed all 197 bundled questions match the retained source.

## Build and launch

- Native Swift/SwiftUI application target, macOS platform only.
- Shared `UniversityAfterDark` scheme with app and hosted XCTest targets.
- Debug build: **BUILD SUCCEEDED**.
- Release build: **BUILD SUCCEEDED**; universal executable contains `arm64` and `x86_64`.
- App launches successfully on the current Apple silicon Mac. Native window, menu bar, welcome screen, setup, gameplay, voting, and fullscreen were inspected through the running app.
- Code signature uses **Sign to Run Locally**. App Sandbox is enabled. No incoming/outgoing network entitlements are present.
- Question JSON, original synthesized WAV effects, and ICNS icon are included in the app's Copy Bundle Resources phase.
- No third-party dependencies or resource downloads.

Build command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project UniversityAfterDark.xcodeproj -scheme UniversityAfterDark \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build
```

## Automated tests

**51 Xcode XCTest cases passed, 0 failures** after the cinematic audio update.

| Suite | Passed |
| --- | ---: |
| QuestionBankTests | 6 |
| GameMechanicsTests | 14 |
| PersistenceAndToolsTests | 7 |
| AppIntegrationTests | 3 |
| AudioPreferencesTests | 4 |
| MusicManagerTests | 15 |
| BundledAudioTests | 2 |

The standalone Swift Package Manager core harness also passed all **31** core cases.

Tests cover bundle loading, total and per-category counts, unique IDs, wording samples, categories/intensities/titles, malformed banks, long custom text, no repeats across every pool, exhaustion and scoped resets, overlapping mode history, sequential/shuffled/manual rotations, next-player previews, player removal/reordering, 2/20-player validation, empty/duplicate names, escalation, Nuclear pools, redraw type/intensity, repeated actions, completion/skip statistics, save/resume/reset, corrupt saves, invalid rotations, custom-question persistence/edit/delete, countdown pause/resume/reset/completion, aggregate-only voting, opt-out, and erasure. A recovery regression verifies that lifecycle saves do not overwrite a corrupt save before an explicit new session/reset.

Run the Xcode test command from the README to generate a local result bundle. Hosted application tests require access to Apple's local test-manager service.

## Question-bank audit

**197 total = 95 original + 102 additional.** No duplicate IDs, missing text, invalid categories, or invalid intensity mappings.

| Round | Original truths | Original dares | Additional truths | Additional dares |
| --- | ---: | ---: | ---: | ---: |
| 1 | 10 | 8 | 10 | 10 |
| 2 | 15 | 8 | 12 | 10 |
| 3 | 15 | 8 | 15 | 10 |
| 4 | 15 | 8 | 15 | 10 |
| Nuclear | 8 group | — | 10 group | — |

`python3 Tools/import_questions.py --check` reparsed the retained source bank and compared all 197 JSON objects field-for-field. Original question wording, titles, paragraph structure, original/additional flags, and assigned categories are retained in the JSON. UI typography only compacts blank paragraph separators.

## Native UI checks

- Welcome layout at the default 1280 × 820 window size.
- Two-player setup with text entry and required age/consent checkboxes; disabled Continue before valid input.
- Configuration cards, intensity selection, and sequential/shuffled order controls.
- Main game, current/next player, Truth keyboard shortcut, redraw, and Space completion.
- Completion rotates Alex → Emma; redraw retains the current player.
- Switching Classic → Nuclear preserves used question IDs and statistics.
- Nuclear title/instructions, Start, Complete/Skip/Redraw, optional local voting.
- Ballot handoff → choice → next handoff; opt-out; disabled totals reveal until consent; aggregate results; close and erase.
- Entering and leaving native fullscreen/presentation, including its large question text and hidden sidebar.
- Resizing to approximately 968 × 712; long content remains scrollable. The final Release build was then verified with controls pinned and visible independently of prompt length.
- Final Release resume gate rechecks age and consent, then restores the active question and turn history.
- Settings-local End Night and Reset confirmations appear above their sheet; End Night opens the summary and Reset returns to the welcome screen with no resumable session. The Settings keyboard command was verified.
- Custom editor, statistics, and session state transitions are additionally covered by app integration tests.

## Practical limits

A physical external display, Intel hardware, and a macOS 15 installation were not available for runtime checks. Both processor architectures compile, and the minimum OS version is encoded in the project and app metadata. External display support uses standard macOS window movement/fullscreen on a single shared window.

Shared-screen ballots cannot guarantee anonymity, particularly in a small group; the app says so before voting and before revealing totals. Paper-based free-text challenges remain paper activities and are never stored. Timers and vote contents do not survive relaunch, while the current challenge and session progress do. Long custom prompts scroll without truncation. Public distribution/notarization is outside the local-use build.

## Cinematic audio update

The updated universal Release build includes twelve original stereo instrumental loops and six sound effects in `Resources/Audio`. All 18 files decode with AVAudioPlayer. Automatic category changes, equal-power fades, retained playback across questions, synchronized Nuclear cues, immediate master mute, independent volumes, persistent preferences, missing/corrupt file handling, stale-load cancellation, and shutdown are covered by the new audio tests. The actual PCM files also passed independent measurements; see `Audio.md` and `AudioValidation.json`. Live UI checks confirmed playback, next track, pause/resume, mute, volume independence, and category selection.
