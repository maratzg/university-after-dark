import SwiftUI
import Combine

struct GameView: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BrandMark()
                Spacer()
                if !vm.settings.presentation {
                    HStack(spacing: 7) {
                        Circle().fill(Night.bright).frame(width: 5, height: 5)
                        Eyebrow(text: "The night is still young")
                    }
                    Spacer()
                }
                MusicQuickControls(manager: vm.music).padding(.trailing, 12)
                IconButton(symbol: "person.2", label: "Edit players", action: vm.openPlayers)
                IconButton(symbol: "chart.bar.xaxis", label: "Session statistics") { vm.modal = .statistics }
                IconButton(symbol: vm.settings.presentation ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", label: "Presentation mode", action: vm.togglePresentation)
                IconButton(symbol: "slider.horizontal.3", label: "Settings") { vm.modal = .settings }
            }.padding(.horizontal, 32).padding(.top, 22).padding(.bottom, 20)
            Hairline()
            HStack(spacing: 0) {
                if !vm.settings.presentation { sidebar.frame(width: 227); Rectangle().fill(Night.border.opacity(0.6)).frame(width: 1) }
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ScrollView {
                            Group {
                                if let question = vm.activeQuestion { QuestionRevealView(vm: vm, question: question, availableHeight: geometry.size.height) }
                                else { FateSelectionView(vm: vm, availableHeight: geometry.size.height) }
                            }.frame(maxWidth: vm.settings.presentation ? 1350 : 1050)
                                .padding(.horizontal, vm.settings.presentation ? 55 : 38).padding(.vertical, 25)
                                .frame(minHeight: vm.activeQuestion == nil ? geometry.size.height : nil)
                                .frame(maxWidth: .infinity)
                        }
                        if let question = vm.activeQuestion {
                            ChallengeControls(vm: vm, question: question).id(question.id)
                                .frame(maxWidth: vm.settings.presentation ? 1350 : 1050)
                                .padding(.horizontal, vm.settings.presentation ? 55 : 38).padding(.vertical, 20)
                                .frame(maxWidth: .infinity).background(Night.background.opacity(0.92))
                        }
                    }
                }
            }.allowsHitTesting(!vm.nuclearRevealPending)
            footer
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Tonight's rules")
                Picker("Game mode", selection: Binding(get: { vm.settings.mode }, set: { mode in vm.updateSettings { $0.mode = mode } })) {
                    ForEach(GameMode.allCases) { Text($0.label).tag($0) }
                }.labelsHidden().pickerStyle(.menu).tint(Night.text)
            }
            VStack(alignment: .leading, spacing: 17) {
                ForEach(1...5, id: \.self) { round in
                    let active = vm.session?.effectiveRound == round
                    HStack(alignment: .top, spacing: 11) {
                        Text(String(format: "%02d", round)).font(Night.label(10)).foregroundStyle(active ? Night.bright : Night.muted.opacity(0.45)).frame(width: 20)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(round == 5 ? "NUCLEAR" : "ROUND \(round)").font(Night.label(9)).tracking(1.4).foregroundStyle(active ? Night.text : Night.muted)
                            if active { Text(Rounds.name(round)).font(Night.serif(14)).foregroundStyle(Night.gold).fixedSize(horizontal: false, vertical: true).lineSpacing(3) }
                        }
                        Spacer(minLength: 0)
                        if active { Circle().fill(Night.bright).frame(width: 4, height: 4).padding(.top, 4) }
                    }
                }
            }
            Hairline()
            HStack { Eyebrow(text: "In the room"); Spacer(); Text("\(vm.session?.players.count ?? 0)").font(Night.label()).foregroundStyle(Night.muted) }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array((vm.session?.players ?? []).enumerated()), id: \.element.id) { index, player in
                        Button { vm.selectPlayer(player.id) } label: {
                            HStack(spacing: 10) {
                                PlayerAvatar(player: player, index: index, size: 28, active: vm.session?.currentPlayerID == player.id)
                                Text(player.name).font(.system(size: 12, weight: vm.session?.currentPlayerID == player.id ? .semibold : .regular)).lineLimit(1)
                                Spacer()
                                if vm.session?.currentPlayerID == player.id { Image(systemName: "arrow.left").font(.system(size: 9)).foregroundStyle(Night.bright) }
                            }.padding(7).background(vm.session?.currentPlayerID == player.id ? Night.card : .clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain).disabled(vm.activeQuestion != nil).help("Make \(player.name) the current player")
                    }
                }
            }.frame(maxHeight: .infinity)
            Button { vm.confirmEnd = true } label: { Label("End the night", systemImage: "moon.zzz").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(Night.muted)
        }.padding(23).background(Night.surface.opacity(0.55))
    }
    private var footer: some View {
        HStack {
            Text("SKIP ANYTHING. EXPLAIN NOTHING.").font(Night.label(8)).tracking(1.2).foregroundStyle(Night.muted)
            Spacer()
            if vm.settings.keyboardHints {
                HStack(spacing: 19) {
                    keyHint("T", "TRUTH"); keyHint("D", "DARE"); keyHint("SPACE", "CONTINUE"); keyHint("S", "SKIP"); keyHint("N", "REDRAW"); keyHint("F", "FULLSCREEN")
                }
            }
        }.padding(.horizontal, 30).padding(.vertical, 15).background(Night.background.opacity(0.8))
    }
    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(Night.label(8)).foregroundStyle(Night.text).padding(.horizontal, 5).padding(.vertical, 3).background(Night.card, in: RoundedRectangle(cornerRadius: 3))
            Text(label).font(Night.label(7)).foregroundStyle(Night.muted)
        }
    }
}

struct FateSelectionView: View {
    @ObservedObject var vm: GameViewModel
    var availableHeight: CGFloat
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 9) {
                Rectangle().fill(Night.crimson).frame(width: 25, height: 1)
                Eyebrow(text: vm.settings.mode == .nuclear ? "Everyone is involved" : "Current player", color: Night.gold)
                Rectangle().fill(Night.crimson).frame(width: 25, height: 1)
            }
            Text(vm.settings.mode == .nuclear ? "The whole room." : (vm.session?.currentPlayer?.name ?? "Your turn"))
                .font(.system(size: vm.settings.presentation ? 76 : 52, weight: .medium, design: .serif))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(vm.nuclearRevealPending ? "The room holds its breath…" : vm.settings.mode == .nuclear ? "There is nowhere to hide. There is always a way to pass." : "Choose your fate.")
                .font(Night.serif(20)).foregroundStyle(Night.muted)
            if vm.settings.mode == .classic || vm.settings.mode == .escalation || vm.settings.mode == .absoluteChaos {
                HStack(spacing: 20) {
                    FateCard(type: .truth, height: max(240, min(340, availableHeight - 300)), reduceMotion: vm.reducedMotion) { vm.draw(.truth) }
                    FateCard(type: .dare, height: max(240, min(340, availableHeight - 300)), reduceMotion: vm.reducedMotion) { vm.draw(.dare) }
                }.padding(.top, 9)
            } else {
                Button(action: vm.drawFate) {
                    VStack(spacing: 19) {
                        Image(systemName: vm.settings.mode == .nuclear ? "sparkle" : "shuffle").font(.system(size: 49, weight: .ultraLight)).foregroundStyle(vm.settings.mode == .nuclear ? Night.gold : Night.bright)
                        Text(vm.settings.mode == .nuclear ? "NUCLEAR" : "RANDOM FATE").font(Night.serif(43)).tracking(5)
                        Eyebrow(text: vm.settings.mode == .nuclear ? "Enter the group round  ↗" : "Let the night decide  ↗", color: Night.gold)
                    }.frame(maxWidth: .infinity).frame(height: max(230, min(310, availableHeight - 300)))
                        .background(Night.burgundy.opacity(0.24), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder((vm.settings.mode == .nuclear ? Night.gold : Night.crimson).opacity(0.65)))
                }.buttonStyle(.plain).padding(.top, 8)
            }
            HStack(spacing: 9) {
                Eyebrow(text: "Next player")
                Text(vm.session?.nextPlayer?.name ?? "—").font(.system(size: 12, weight: .semibold))
                Button { vm.skipPlayer() } label: { Text("Skip turn →").font(.system(size: 11)).foregroundStyle(Night.muted) }.buttonStyle(.plain).padding(.leading, 18)
            }.padding(.top, 8)
        }.frame(maxWidth: .infinity)
    }
}

struct FateCard: View {
    var type: QuestionType
    var height: CGFloat
    var reduceMotion: Bool
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack { Text(type == .truth ? "I" : "II").font(Night.label()); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 12)) }.foregroundStyle(Night.bright.opacity(0.7))
                Spacer(minLength: 15)
                Text(type == .truth ? "?" : "!").font(.system(size: height * 0.34, weight: .ultraLight, design: .serif)).foregroundStyle(type == .truth ? Night.bright : Color(hex: 0xD66C86))
                    .shadow(color: Night.crimson.opacity(0.6), radius: hovered ? 30 : 12)
                Spacer(minLength: 10)
                Text(type.label).font(Night.serif(32)).tracking(7)
                Text(type == .truth ? "SAY THE UNSAID" : "CROSS YOUR OWN LINE").font(Night.label(8)).tracking(2.5).foregroundStyle(Night.muted).padding(.top, 11)
            }.padding(25).frame(maxWidth: .infinity).frame(height: height)
                .background(LinearGradient(colors: [Night.burgundy.opacity(type == .truth ? 0.65 : 0.2), Night.surface, Night.burgundy.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(hovered ? Night.bright : Night.crimson.opacity(type == .truth ? 0.6 : 0.3), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Night.crimson.opacity(0.12), lineWidth: 0.7).padding(8))
                .scaleEffect(hovered && !reduceMotion ? 1.018 : 1)
                .shadow(color: Night.crimson.opacity(hovered ? 0.17 : 0.04), radius: 27, y: 8)
        }.buttonStyle(.plain).onHover { hovered = $0 }.animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: hovered)
        .accessibilityLabel("Choose \(type.rawValue)")
    }
}

struct QuestionRevealView: View {
    @ObservedObject var vm: GameViewModel
    var question: Question
    var availableHeight: CGFloat
    var nuclear: Bool { question.type == .nuclear }
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: nuclear ? "Everyone is involved" : "Current player", color: nuclear ? Night.gold : Night.muted)
                    Text(nuclear ? "The whole room" : (vm.session?.currentPlayer?.name ?? "")).font(.system(size: vm.settings.presentation ? 44 : 24, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Eyebrow(text: "Round \(question.round)")
                    HStack(spacing: 4) {
                        ForEach(0..<10, id: \.self) { i in Capsule().fill(i < question.intensity ? (nuclear ? Night.gold : Night.crimson) : Night.border).frame(width: 4, height: 10) }
                        Text("\(question.intensity)/10").font(Night.label(9)).foregroundStyle(Night.muted).padding(.leading, 5)
                    }.accessibilityLabel("Intensity \(question.intensity) out of 10")
                }
            }
            VStack(spacing: 21) {
                HStack {
                    Eyebrow(text: question.type.label, color: nuclear ? Night.gold : Night.bright)
                    Spacer()
                    Text(question.isCustom ? "HOUSE EDITION" : question.isOriginal ? "THE ORIGINAL COLLECTION" : "AFTER HOURS COLLECTION")
                        .font(Night.label(7)).tracking(1.4).foregroundStyle(Night.muted)
                }
                Spacer(minLength: 0)
                if let title = question.title { Text(title).font(Night.serif(nuclear ? 33 : 21)).tracking(nuclear ? 4 : 1.3).foregroundStyle(nuclear ? Night.gold : Night.text).multilineTextAlignment(.center) }
                Text(question.text.replacingOccurrences(of: "\n\n", with: "\n"))
                    .font(Night.serif(questionFont)).lineSpacing(nuclear ? 6 : 8).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                    .padding(.vertical, 12).accessibilityAddTraits(.isStaticText)
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    Image(systemName: "lock.open").font(.system(size: 10))
                    Text(question.requiresOtherPlayers ? "Only with willing players. Every part is optional." : "Share only what you choose. Passing needs no explanation.")
                        .font(.system(size: 11))
                }.foregroundStyle(Night.muted)
            }.padding(vm.settings.presentation ? 36 : 29)
                .frame(minHeight: max(280, min(380, availableHeight - 270)))
                .background(LinearGradient(colors: [nuclear ? Color(hex: 0x211C14) : Color(hex: 0x211219), Night.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder((nuclear ? Night.gold : Night.crimson).opacity(0.55)))
                .shadow(color: Night.crimson.opacity(0.1), radius: 35).id(question.id)
                .transition(.opacity.combined(with: .scale(scale: vm.reducedMotion ? 1 : 0.98)))
        }
    }

    private var questionFont: CGFloat {
        if vm.settings.presentation { return question.text.count > 220 ? 37 : 48 }
        if nuclear { return question.text.count > 220 ? 24 : 28 }
        return question.text.count > 240 ? 25 : question.text.count > 150 ? 29 : 34
    }
}

/// Actions remain visible while long prompts scroll above them.
struct ChallengeControls: View {
    @ObservedObject var vm: GameViewModel
    var question: Question
    @State private var timerVisible = false
    var nuclear: Bool { question.type == .nuclear }
    var body: some View {
        VStack(spacing: 18) {
            if nuclear && vm.session?.nuclearStarted == false {
                VStack(spacing: 13) {
                    Text("Read the challenge together. Confirm everyone involved wants to play.").font(.system(size: 12)).foregroundStyle(Night.muted)
                    HStack(spacing: 14) {
                        NightButton(title: "Start challenge", symbol: "play", gold: true, action: vm.startNuclear)
                        NightButton(title: "Skip", primary: false) { vm.finish(skipped: true) }
                        NightButton(title: "New challenge", primary: false, action: vm.newQuestion)
                    }
                }
            } else {
                HStack(spacing: 14) {
                    NightButton(title: nuclear ? "Complete" : "Done", symbol: "checkmark", gold: nuclear) { vm.finish() }
                    NightButton(title: "Skip", primary: false) { vm.finish(skipped: true) }
                    NightButton(title: "New question", symbol: "arrow.clockwise", primary: false, action: vm.newQuestion)
                    if !nuclear {
                        IconButton(symbol: "timer", label: "Optional timer") { timerVisible.toggle() }
                        if question.voting != nil { IconButton(symbol: "chart.bar", label: "Open optional local voting", action: vm.beginVoting) }
                    }
                }
            }
            if nuclear && vm.session?.nuclearStarted == true {
                HStack(spacing: 18) {
                    Button { timerVisible.toggle() } label: { Label("Optional timer", systemImage: "timer") }
                    if question.voting != nil { Button(action: vm.beginVoting) { Label("Optional local voting", systemImage: "chart.bar") } }
                }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Night.gold)
            }
            if timerVisible || (question.timerSeconds != nil && (!nuclear || vm.session?.nuclearStarted == true)) { CountdownTimerView(vm: vm) }
            HStack(spacing: 11) {
                Text("DRAW \(String(format: "%03d", vm.session?.statistics.drawn ?? 0))").font(Night.label(8)).tracking(1.2)
                Rectangle().fill(Night.border).frame(width: 33, height: 1)
                Text("\(vm.session?.randomizer.usedIDs.count ?? 0) SEEN / \(vm.allQuestions.count) IN THE DECK").font(Night.label(8)).tracking(1.2)
                Spacer()
                Text("NEXT  ·  \(vm.session?.nextPlayer?.name.uppercased() ?? "")").font(Night.label(8)).tracking(1.2)
            }.foregroundStyle(Night.muted)
        }
    }
}

struct CountdownTimerView: View {
    @ObservedObject var vm: GameViewModel
    @State private var now = ProcessInfo.processInfo.systemUptime
    private let ticks = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 21) {
            ZStack {
                Circle().stroke(Night.border, lineWidth: 2)
                Circle().trim(from: 0, to: vm.timer.progress(at: now)).stroke(Night.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int(ceil(vm.timer.remaining(at: now))))").font(.system(size: 18, weight: .light, design: .monospaced))
            }.frame(width: 60, height: 60).accessibilityLabel("\(Int(ceil(vm.timer.remaining(at: now)))) seconds remaining")
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: vm.timer.remaining(at: now) <= 0 ? "Time. Take all you need." : "An invitation, never a deadline", color: Night.gold)
                HStack(spacing: 18) {
                    Button(vm.timer.isRunning ? "Pause" : vm.timer.remaining(at: now) < vm.timer.duration ? "Resume" : "Start") {
                        now = ProcessInfo.processInfo.systemUptime
                        if vm.timer.isRunning { vm.timer.pause(at: now) } else { vm.timer.start(at: now) }
                    }.disabled(vm.timer.remaining(at: now) <= 0)
                    Button("Reset") { vm.timer.reset() }
                    ForEach([30, 60, 120], id: \.self) { seconds in
                        Button("\(seconds)s") { vm.timer.configure(seconds: seconds) }.foregroundStyle(vm.timer.duration == Double(seconds) ? Night.gold : Night.muted)
                    }
                }.buttonStyle(.plain).font(.system(size: 11))
            }
            Spacer()
        }.padding(15).background(Night.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
            .onReceive(ticks) { _ in now = ProcessInfo.processInfo.systemUptime; vm.timer.tick(at: now) }
            .onDisappear { vm.timer.pause(at: ProcessInfo.processInfo.systemUptime) }
    }
}
