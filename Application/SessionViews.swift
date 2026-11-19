import SwiftUI

struct RulesView: View {
    @ObservedObject var vm: GameViewModel
    private var resumeGate: Bool { vm.canResume && vm.screen == .welcome }
    var body: some View {
        ModalShell(title: "A little discretion.", subtitle: "The house rules", dismiss: { vm.modal = nil }) {
            VStack(alignment: .leading, spacing: 25) {
                Text("Truths reveal. Dares challenge. Consent decides.").font(Night.serif(25))
                HStack(alignment: .top, spacing: 25) {
                    step("01", "Gather the room", "Add 2–20 adults, choose a mode, and set the intensity.")
                    step("02", "Choose your fate", "On your turn, choose Truth or Dare. Random Fate decides for you; Nuclear brings in everyone.")
                    step("03", "Keep it voluntary", "Complete, redraw, or skip. Every choice is equally valid. Nobody owes the room an explanation.")
                }
                Hairline()
                VStack(alignment: .leading, spacing: 13) {
                    rule("18+ only. Everyone must freely agree to participate.")
                    rule("Anyone can skip any question or dare, or any part of it, without penalty.")
                    rule("No forced kissing, touching, undressing, or drinking. Involving someone else requires their voluntary agreement.")
                    rule("Being intoxicated is not consent. No dangerous physical challenges.")
                    rule("No pressure to reveal private messages, contact ex-partners or strangers, or disclose someone else's secrets.")
                    rule("No recording or sharing without everyone's consent.")
                }
                Text("Intensity rises from 6 to 10. It means more revealing conversation and social tension; consent stays the same at every level.")
                    .font(.system(size: 12)).foregroundStyle(Night.muted).lineSpacing(5)
                if resumeGate {
                    Hairline()
                    Toggle("Every player is 18 or older.", isOn: $vm.ageConfirmed)
                    Toggle("Everyone freely agrees to play and can pass without pressure.", isOn: $vm.consentConfirmed)
                    NightButton(title: "Resume the night", symbol: "arrow.right", action: vm.confirmResume).disabled(!vm.ageConfirmed || !vm.consentConfirmed)
                } else { NightButton(title: "Understood", symbol: "checkmark") { vm.modal = nil } }
            }.toggleStyle(.checkbox).tint(Night.crimson)
        }
    }
    private func step(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: number, color: Night.bright)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(text).font(.system(size: 12)).foregroundStyle(Night.muted).lineSpacing(5)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) { Circle().fill(Night.crimson).frame(width: 4, height: 4).padding(.top, 6); Text(text).font(.system(size: 13)).lineSpacing(4) }
    }
}

struct SettingsView: View {
    @ObservedObject var vm: GameViewModel
    @State private var resetRequested = false
    @State private var endRequested = false
    var body: some View {
        ModalShell(title: "Set your own limits.", subtitle: "Settings · saved on this Mac", dismiss: { vm.modal = nil }) {
            VStack(alignment: .leading, spacing: 24) {
                section("The game") {
                    Picker("Game mode", selection: setting(\.mode)) { ForEach(GameMode.allCases) { Text($0.label).tag($0) } }
                    Text("Mode changes preserve the current challenge, statistics, and used questions.").font(.system(size: 11)).foregroundStyle(Night.muted)
                    RoundPicker(vm: vm).disabled(vm.settings.mode == .nuclear)
                    Picker("Player order", selection: setting(\.order)) { Text("Sequential").tag(PlayerOrder.sequential); Text("Shuffle each cycle").tag(PlayerOrder.shuffled) }
                    if vm.session != nil { Button("Restart turn rotation", action: vm.restartRotation).foregroundStyle(Night.gold) }
                }
                section("Atmosphere") {
                    HStack { Text("Animation intensity"); Slider(value: setting(\.animationIntensity), in: 0...1).frame(width: 250); Text("\(Int(vm.settings.animationIntensity * 100))%").monospacedDigit().foregroundStyle(Night.muted) }
                    Toggle("Reduce motion", isOn: setting(\.reducedMotion))
                    Text("The system Reduce Motion preference is also respected.").font(.system(size: 11)).foregroundStyle(Night.muted)
                    Toggle("Keyboard shortcut hints", isOn: setting(\.keyboardHints))
                    Toggle("Presentation mode", isOn: Binding(get: { vm.settings.presentation }, set: { _ in vm.togglePresentation() }))
                    Text("Large type and minimal controls. Use F for fullscreen, or move the window to an external display before entering fullscreen.").font(.system(size: 11)).foregroundStyle(Night.muted).lineSpacing(4)
                }
                section("The soundstage") { MusicControlPanel(manager: vm.music) }
                section("Your edition") {
                    Toggle("Include custom questions", isOn: setting(\.customEnabled))
                    HStack { Text("\(vm.state.customQuestions.count) custom challenges").foregroundStyle(Night.muted); Spacer(); NightButton(title: "Edit question bank", primary: false, compact: true) { vm.modal = .custom } }
                }
                if vm.session != nil {
                    Hairline()
                    HStack {
                        NightButton(title: "Reset session", primary: false, compact: true) { resetRequested = true }
                        Spacer()
                        NightButton(title: "End the night", compact: true) { endRequested = true }
                    }
                }
                Text("Offline by design. No accounts, analytics, recorded answers, or network requests. Names, settings, questions, and session progress stay in local app storage. Vote totals are erased when their challenge ends.")
                    .font(.system(size: 11)).foregroundStyle(Night.muted).lineSpacing(5)
            }.font(.system(size: 13)).toggleStyle(.switch).tint(Night.crimson)
        }
        .confirmationDialog("Reset this session?", isPresented: $resetRequested, titleVisibility: .visible) {
            Button("Reset session", role: .destructive) { vm.resetSession() }
        } message: { Text("This clears session progress and question history. Players, settings, and custom questions stay saved.") }
        .confirmationDialog("End this night?", isPresented: $endRequested, titleVisibility: .visible) {
            Button("End the night") { vm.modal = nil; vm.end() }
        } message: { Text("Your session statistics will be saved. You can start a new night afterward.") }
    }
    private func setting<T>(_ keyPath: WritableKeyPath<GameSettings, T>) -> Binding<T> {
        Binding(get: { vm.settings[keyPath: keyPath] }, set: { value in vm.updateSettings { $0[keyPath: keyPath] = value } })
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) { Eyebrow(text: title, color: Night.gold); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatisticsGrid: View {
    var stats: SessionStatistics
    var round: Int
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 3), spacing: 15) {
            metric("Questions drawn", stats.drawn, "The night kept asking.")
            metric("Truths completed", stats.truths, "A little more understood.")
            metric("Dares completed", stats.dares, "A moment worth remembering.")
            metric("Challenges skipped", stats.skipped, "Boundaries respected.")
            metric("Nuclear completed", stats.nuclear, "The room came together.")
            metric("Turns played", stats.turns, "Everyone has a place here.")
        }
    }
    private func metric(_ title: String, _ value: Int, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(Night.label(8)).tracking(1.4).foregroundStyle(Night.muted)
            Text(String(format: "%02d", value)).font(Night.serif(49)).foregroundStyle(Night.gold)
            Text(caption).font(.system(size: 10)).foregroundStyle(Night.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(Night.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Night.border.opacity(0.7)))
    }
}

struct StatisticsView: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        ModalShell(title: "The night, in numbers.", subtitle: "Session statistics", dismiss: { vm.modal = nil }) {
            if let session = vm.session {
                VStack(alignment: .leading, spacing: 25) {
                    HStack { Text("Round \(session.effectiveRound) · \(Rounds.name(session.effectiveRound))").font(Night.serif(22)); Spacer() }
                    StatisticsGrid(stats: session.statistics, round: session.effectiveRound)
                    Text("No leaderboards. No scores for disclosure. Just a shared night.").font(.system(size: 12)).foregroundStyle(Night.muted)
                    NightButton(title: "Back to the room", primary: false) { vm.modal = nil }
                }
            } else { EmptyState(title: "The story starts with you.", message: "Start a night to see your session statistics.") }
        }
    }
}

struct EndGameView: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(label: "Until the next bad idea", music: vm.music)
            Hairline().padding(.horizontal, 44)
            ScrollView {
                VStack(spacing: 25) {
                    Eyebrow(text: "Some things stay after the lights come on", color: Night.gold)
                    Text("What a night.").font(Night.serif(72)).italic()
                    Text("The questions are over. The conversations don't have to be.").font(Night.serif(21)).foregroundStyle(Night.muted)
                    if let session = vm.session { StatisticsGrid(stats: session.statistics, round: session.effectiveRound).padding(.vertical, 15) }
                    HStack(spacing: 16) {
                        NightButton(title: "One more night", symbol: "arrow.up.right", action: vm.beginSetup)
                        NightButton(title: "Back to welcome", primary: false) { vm.screen = .welcome }
                    }
                    Text("Thanks for respecting each other's boundaries.").font(.system(size: 12)).foregroundStyle(Night.muted)
                }.padding(44).frame(maxWidth: 950).frame(maxWidth: .infinity)
            }
        }
    }
}

struct CustomQuestionsView: View {
    @ObservedObject var vm: GameViewModel
    @State private var editingID: String?
    @State private var type: QuestionType = .truth
    @State private var round = 1
    @State private var title = ""
    @State private var text = ""
    @State private var others = false
    @State private var timed = false
    @State private var seconds = 60
    var body: some View {
        ModalShell(title: "Make it personal.", subtitle: "Your private question bank", dismiss: { vm.modal = nil }) {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    Picker("Type", selection: $type) { ForEach(QuestionType.allCases) { Text($0.label).tag($0) } }
                    Picker("Intensity", selection: $round) { ForEach(1...4, id: \.self) { Text("\(Rounds.intensity($0))/10 · Round \($0)").tag($0) } }.disabled(type == .nuclear)
                }
                TextField(type == .nuclear ? "Title (required)" : "Title (optional)", text: $title).textFieldStyle(.roundedBorder)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty { Text("Write your question or challenge…").foregroundStyle(Night.muted).padding(8) }
                    TextEditor(text: $text).scrollContentBackground(.hidden).padding(3)
                }.frame(height: 105).background(Night.card, in: RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Night.border))
                Toggle("Involves other willing players", isOn: $others)
                HStack { Toggle("Optional timer", isOn: $timed); if timed { Picker("Seconds", selection: $seconds) { ForEach([30, 60, 120], id: \.self) { Text("\($0) seconds").tag($0) } }.frame(width: 170) } }
                HStack {
                    Text("Custom wording stays on this Mac.").font(.system(size: 11)).foregroundStyle(Night.muted)
                    Spacer()
                    if editingID != nil { Button("Cancel edit", action: clear).foregroundStyle(Night.muted) }
                    NightButton(title: editingID == nil ? "Add question" : "Save changes", compact: true, action: save)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (type == .nuclear && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
                Hairline()
                HStack { Eyebrow(text: "House collection · \(vm.state.customQuestions.count)", color: Night.gold); Spacer(); Toggle("Enabled", isOn: Binding(get: { vm.settings.customEnabled }, set: { value in vm.updateSettings { $0.customEnabled = value } })).toggleStyle(.checkbox) }
                if vm.state.customQuestions.isEmpty { Text("A blank page. A dangerous amount of possibility.").font(Night.serif(21)).foregroundStyle(Night.muted).padding(.vertical, 10) }
                ForEach(vm.state.customQuestions) { question in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "\(question.type.label) · \(question.intensity)/10")
                            if let title = question.title { Text(title).font(.system(size: 12, weight: .semibold)) }
                            Text(question.text).font(.system(size: 12)).foregroundStyle(Night.muted).lineSpacing(4)
                        }
                        Spacer()
                        IconButton(symbol: "pencil", label: "Edit question") { edit(question) }
                        IconButton(symbol: "trash", label: "Delete question") { vm.removeCustom(question.id); if editingID == question.id { clear() } }
                    }.padding(15).background(Night.card, in: RoundedRectangle(cornerRadius: 6))
                }
            }.font(.system(size: 13)).tint(Night.crimson)
        }
    }
    private func save() {
        let selectedRound = type == .nuclear ? 5 : round
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = Question(id: editingID ?? "custom_\(UUID().uuidString)", type: type, round: selectedRound, intensity: Rounds.intensity(selectedRound), title: title.isEmpty ? nil : title, text: text.trimmingCharacters(in: .whitespacesAndNewlines), isOriginal: false, requiresOtherPlayers: others || type == .nuclear, timerSeconds: timed ? seconds : nil, voting: nil)
        vm.addCustom(question); clear()
    }
    private func edit(_ question: Question) {
        editingID = question.id; type = question.type; round = min(4, question.round); title = question.title ?? ""; text = question.text; others = question.requiresOtherPlayers; timed = question.timerSeconds != nil; seconds = question.timerSeconds ?? 60
    }
    private func clear() { editingID = nil; title = ""; text = ""; others = false; timed = false }
}
