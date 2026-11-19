import SwiftUI

struct IntroView: View {
    @ObservedObject var vm: GameViewModel
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            Eyebrow(text: "An invitation to say too much", color: Night.gold)
            VStack(spacing: -4) {
                Text("UNIVERSITY").tracking(14)
                Text("AFTER DARK").tracking(11).foregroundStyle(Night.bright)
            }.font(Night.serif(67)).multilineTextAlignment(.center)
            Text("Some questions should never be asked.").font(Night.serif(20)).foregroundStyle(Night.muted)
            Spacer()
            NightButton(title: "Enter the night", symbol: "arrow.right", action: vm.enter).opacity(appeared ? 1 : 0)
            Button("Skip intro  ·  SPACE") { vm.enter() }.buttonStyle(.plain).font(Night.label()).foregroundStyle(Night.muted).padding(.bottom, 35)
        }
        .opacity(appeared ? 1 : 0.1).scaleEffect(appeared || vm.reducedMotion ? 1 : 0.98)
        .onAppear { withAnimation(vm.reducedMotion ? nil : .easeOut(duration: 1.1)) { appeared = true } }
        .overlay(alignment: .topTrailing) { MusicQuickControls(manager: vm.music).padding(30) }
        .task {
            try? await Task.sleep(for: .seconds(vm.reducedMotion ? 0.15 : 2.4))
            guard !Task.isCancelled, vm.screen == .intro else { return }
            vm.enter()
        }
    }
}

struct PageHeader: View {
    var label: String
    var back: (() -> Void)? = nil
    var settings: (() -> Void)? = nil
    var music: MusicManager? = nil
    var body: some View {
        HStack {
            if let back { IconButton(symbol: "arrow.left", label: "Back", action: back).padding(.trailing, 12) }
            BrandMark()
            Spacer()
            Eyebrow(text: label)
            if let music { MusicQuickControls(manager: music).padding(.leading, 16) }
            if let settings { IconButton(symbol: "slider.horizontal.3", label: "Settings", action: settings).padding(.leading, 18) }
        }.padding(.horizontal, 44).padding(.top, 24).padding(.bottom, 22)
    }
}

struct WelcomeView: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                PageHeader(label: "An after-hours experience", settings: { vm.modal = .settings }, music: vm.music)
                Hairline().padding(.horizontal, 44)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 23) {
                        HStack(spacing: 10) {
                            Circle().fill(Night.bright).frame(width: 5, height: 5)
                            Eyebrow(text: "Leave your good reputation at the door", color: Night.gold)
                        }
                        VStack(alignment: .leading, spacing: -7) {
                            Text("University").foregroundStyle(Night.text)
                            Text("After Dark.").italic().foregroundStyle(Night.bright)
                        }.font(Night.serif(geometry.size.width < 1100 ? 69 : 89)).lineLimit(1).minimumScaleFactor(0.7)
                            .accessibilityElement(children: .ignore).accessibilityLabel("University After Dark")
                        Text("Some questions should\nnever be asked.").font(Night.serif(25)).lineSpacing(3)
                        Text("The friendship-destroying, relationship-testing,\nacademically irresponsible edition.")
                            .font(.system(size: 13)).foregroundStyle(Night.muted).lineSpacing(6)
                        HStack(spacing: 15) {
                            NightButton(title: "Start the night", symbol: "arrow.up.right", action: vm.beginSetup)
                            NightButton(title: "How to play", primary: false) { vm.modal = .rules }
                        }.padding(.top, 7)
                        if vm.canResume {
                            Button { vm.resume() } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Resume your night").underline()
                                    Text("· \(vm.session?.statistics.turns ?? 0) turns played").foregroundStyle(Night.muted)
                                }.font(.system(size: 12))
                            }.buttonStyle(.plain).foregroundStyle(Night.gold)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    InvitationDeck(reduceMotion: vm.reducedMotion).frame(width: geometry.size.width * 0.33, height: 430).padding(.trailing, 10)
                }.padding(.horizontal, 64).frame(maxHeight: .infinity)
                HStack(alignment: .center, spacing: 40) {
                    welcomeFact("\(vm.bank.count)", "QUESTIONS BETTER LEFT UNASKED")
                    Rectangle().fill(Night.border).frame(width: 1, height: 38)
                    welcomeFact("05", "WAYS TO LOSE YOUR COMPOSURE")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("18+ ONLY").font(Night.label(11)).tracking(2).foregroundStyle(Night.gold)
                        Text("All secrets stay in this room.").font(.system(size: 11)).foregroundStyle(Night.muted)
                    }
                }.padding(.horizontal, 64).padding(.vertical, 27).background(Night.surface.opacity(0.5))
            }
        }
    }
    private func welcomeFact(_ value: String, _ label: String) -> some View {
        HStack(alignment: .center, spacing: 15) {
            Text(value).font(Night.serif(34))
            Text(label).font(Night.label(8)).tracking(1.6).foregroundStyle(Night.muted).frame(maxWidth: 160, alignment: .leading).lineSpacing(5)
        }
    }
}

struct InvitationDeck: View {
    var reduceMotion: Bool
    @State private var hovered = false
    var body: some View {
        ZStack {
            Circle().stroke(Night.crimson.opacity(0.13), lineWidth: 1).frame(width: 420, height: 420)
            Circle().stroke(Night.crimson.opacity(0.09), lineWidth: 1).frame(width: 500, height: 500)
            invitation(face: false).rotationEffect(.degrees(15)).offset(x: 36, y: -10)
            invitation(face: false).rotationEffect(.degrees(-13)).offset(x: -29, y: 8)
            invitation(face: true).rotationEffect(.degrees(hovered && !reduceMotion ? -2 : -5)).offset(y: -4)
                .shadow(color: Night.crimson.opacity(0.22), radius: 55, x: 0, y: 15)
        }.onHover { hovered = $0 }.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: hovered)
            .accessibilityHidden(true)
    }
    private func invitation(face: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(hex: 0x29101A), Night.surface, Color(hex: 0x200B13)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 13).strokeBorder(face ? Night.crimson.opacity(0.65) : Night.border, lineWidth: 1)
            RoundedRectangle(cornerRadius: 7).strokeBorder(Night.gold.opacity(face ? 0.25 : 0.07), lineWidth: 0.7).padding(12)
            if face {
                VStack {
                    HStack { Text("U / AD"); Spacer(); Text("I") }.font(Night.label(9)).tracking(2).foregroundStyle(Night.gold)
                    Spacer()
                    ZStack {
                        Circle().stroke(Night.crimson.opacity(0.5), lineWidth: 0.6).frame(width: 120, height: 120)
                        Circle().stroke(Night.gold.opacity(0.3), lineWidth: 0.5).frame(width: 143, height: 143)
                        Text("?").font(.system(size: 115, weight: .ultraLight, design: .serif)).foregroundStyle(Night.bright).offset(y: -5)
                    }
                    Spacer()
                    Text("TRUTH OR DARE").font(Night.label(10)).tracking(4)
                    Text("SOME THINGS CHANGE AFTER MIDNIGHT").font(Night.label(5)).tracking(1.2).foregroundStyle(Night.muted).padding(.top, 6)
                }.padding(28)
            }
        }.frame(width: 250, height: 354)
    }
}

struct PlayerSetupView: View {
    @ObservedObject var vm: GameViewModel
    var inSession: Bool
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(label: "01 / The guest list", back: { vm.screen = .welcome }, music: vm.music)
            Hairline().padding(.horizontal, 44)
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Good company. Questionable decisions.", color: Night.gold)
                        Text("Who's staying up?").font(Night.serif(51))
                        Text("2–20 adults. First names, nicknames, or carefully constructed alter egos.")
                            .font(.system(size: 14)).foregroundStyle(Night.muted)
                    }
                    PlayerEditor(vm: vm, inSession: inSession)
                }.padding(44).frame(maxWidth: 1050)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct PlayerEditor: View {
    @ObservedObject var vm: GameViewModel
    var inSession: Bool
    @FocusState private var focusedID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(vm.draftPlayers.enumerated()), id: \.element.id) { index, player in
                    HStack(spacing: 13) {
                        PlayerAvatar(player: player, index: index, size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "Guest \(String(format: "%02d", index + 1))")
                            TextField("Player name", text: Binding(get: { vm.draftPlayers.first(where: { $0.id == player.id })?.name ?? "" }, set: { text in
                                if let index = vm.draftPlayers.firstIndex(where: { $0.id == player.id }) { vm.draftPlayers[index].name = String(text.prefix(40)) }
                            })).textFieldStyle(.plain).font(.system(size: 17, weight: .medium)).focused($focusedID, equals: player.id)
                                .accessibilityLabel("Guest \(index + 1) name")
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 2) {
                            Button { move(player.id, by: -1) } label: { Image(systemName: "chevron.up") }.disabled(index == 0).help("Move earlier")
                            Button { move(player.id, by: 1) } label: { Image(systemName: "chevron.down") }.disabled(index == vm.draftPlayers.count - 1).help("Move later")
                        }.buttonStyle(.plain).font(.system(size: 9)).foregroundStyle(Night.muted)
                        Button { vm.draftPlayers.removeAll { $0.id == player.id } } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                            .buttonStyle(.plain).foregroundStyle(Night.muted).help("Remove \(player.name)")
                    }.padding(17).background(Night.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(focusedID == player.id ? Night.crimson : Night.border.opacity(0.65)))
                }
            }
            HStack(spacing: 20) {
                NightButton(title: "Add a guest", symbol: "plus", primary: false, compact: true) {
                    let player = Player(name: ""); vm.draftPlayers.append(player); focusedID = player.id
                }.disabled(vm.draftPlayers.count >= 20)
                Button { vm.draftPlayers.shuffle() } label: { Label("Shuffle the guest list", systemImage: "shuffle").font(.system(size: 12)) }.buttonStyle(.plain).foregroundStyle(Night.muted)
                Spacer()
                Text("\(vm.draftPlayers.count) / 20").font(Night.label()).foregroundStyle(Night.muted)
            }
            if !inSession {
                Hairline().padding(.vertical, 7)
                VStack(alignment: .leading, spacing: 13) {
                    Toggle("Every player is 18 or older.", isOn: $vm.ageConfirmed)
                    Toggle("Everyone freely agrees to play and can skip anything, without pressure or penalty.", isOn: $vm.consentConfirmed)
                    Button("Read our house rules") { vm.modal = .rules }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Night.gold)
                }.toggleStyle(.checkbox).font(.system(size: 13)).tint(Night.crimson)
            }
            if let validation = PlayerValidation.error(for: vm.draftPlayers) {
                Text(validation).font(.system(size: 12)).foregroundStyle(Night.gold)
            }
            HStack {
                Text(inSession ? "The active player stays in place whenever possible." : "Names stay on this Mac. No accounts. No audience.")
                    .font(.system(size: 11)).foregroundStyle(Night.muted)
                Spacer()
                NightButton(title: inSession ? "Save guest list" : "Set the mood", symbol: "arrow.right") { vm.savePlayers(inSession: inSession) }
                    .disabled(PlayerValidation.error(for: vm.draftPlayers) != nil || (!inSession && (!vm.ageConfirmed || !vm.consentConfirmed)))
            }.padding(.top, 8)
        }
    }
    private func move(_ id: UUID, by delta: Int) {
        guard let index = vm.draftPlayers.firstIndex(where: { $0.id == id }), vm.draftPlayers.indices.contains(index + delta) else { return }
        vm.draftPlayers.swapAt(index, index + delta)
    }
}

struct ConfigurationView: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(label: "02 / Set the mood", back: { vm.screen = .players }, music: vm.music)
            Hairline().padding(.horizontal, 44)
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    Eyebrow(text: "The night has five personalities", color: Night.gold)
                    Text("How far will you go?").font(Night.serif(48))
                    modeSelection
                    HStack(alignment: .top, spacing: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: vm.settings.mode == .absoluteChaos ? "Unlock through round" : vm.settings.mode == .escalation ? "Starting intensity" : "Question intensity")
                            RoundPicker(vm: vm).disabled(vm.settings.mode == .nuclear).opacity(vm.settings.mode == .nuclear ? 0.35 : 1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow(text: "Turn order")
                            Picker("Turn order", selection: Binding(get: { vm.settings.order }, set: { order in vm.updateSettings { $0.order = order } })) {
                                Text("Around the room").tag(PlayerOrder.sequential)
                                Text("Shuffle each cycle").tag(PlayerOrder.shuffled)
                            }.pickerStyle(.segmented).labelsHidden()
                            Text("Escalation rises one level per rotation; level 10 stays unlocked.").font(.system(size: 11)).foregroundStyle(Night.muted)
                        }.frame(width: 290)
                    }.padding(.vertical, 5)
                    Hairline()
                    HStack {
                        HStack(spacing: -7) { ForEach(Array(vm.state.players.prefix(6).enumerated()), id: \.element.id) { i, p in PlayerAvatar(player: p, index: i, size: 32).overlay(Circle().stroke(Night.background, lineWidth: 2)) } }
                        Text("\(vm.state.players.count) guests on the list").font(.system(size: 12)).foregroundStyle(Night.muted).padding(.leading, 8)
                        Spacer()
                        NightButton(title: "Let the night begin", symbol: "arrow.up.right", gold: vm.settings.mode == .nuclear, action: vm.start)
                    }
                }.padding(44).frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
        }
    }
    private var modeSelection: some View {
        HStack(spacing: 11) {
            ForEach(GameMode.allCases) { mode in
                Button { vm.updateSettings { $0.mode = mode } } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text(mode.numeral).font(Night.serif(27)).foregroundStyle(mode == .nuclear ? Night.gold : Night.bright); Spacer(); if vm.settings.mode == mode { Image(systemName: "checkmark.circle.fill").foregroundStyle(Night.bright) } }
                        Text(mode.label).font(.system(size: 15, weight: .semibold))
                        Text(mode.summary).font(.system(size: 11)).foregroundStyle(Night.muted).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }.padding(19).frame(maxWidth: .infinity, alignment: .leading).frame(height: 185)
                    .background(vm.settings.mode == mode ? Night.burgundy.opacity(0.35) : Night.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(vm.settings.mode == mode ? Night.crimson : Night.border.opacity(0.6)))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}

struct RoundPicker: View {
    @ObservedObject var vm: GameViewModel
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { round in
                Button { vm.updateSettings { $0.round = round } } label: {
                    VStack(spacing: 7) {
                        Text("\(Rounds.intensity(round))").font(.system(size: 20, weight: .light, design: .serif))
                        Text("ROUND \(round)").font(Night.label(7)).tracking(1)
                    }.foregroundStyle(vm.settings.round == round ? Night.text : Night.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(vm.settings.round == round ? Night.crimson.opacity(0.25) : Night.card, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(vm.settings.round == round ? Night.crimson : Night.border))
                }.buttonStyle(.plain).help(Rounds.name(round))
            }
        }
    }
}
