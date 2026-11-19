import SwiftUI
import AppKit

@main
struct UniversityAfterDarkApp: App {
    @StateObject private var game = GameViewModel()
    var body: some Scene {
        Window("University After Dark", id: "main") {
            RootView(vm: game)
                .frame(minWidth: 960, minHeight: 680)
                .preferredColorScheme(.dark)
                .background(WindowConfiguration())
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("The Night") {
                Button("How to Play") { game.modal = .rules }
                Button("Session Statistics") { game.modal = .statistics }.disabled(game.session == nil)
                Button("Edit Players") { game.openPlayers() }.disabled(game.session == nil)
                Divider()
                Button("Presentation Mode") { game.togglePresentation() }.keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Mute / Unmute All Audio") { game.music.toggleAllMute() }.keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { game.modal = .settings }.keyboardShortcut(",")
            }
        }
    }
}

private struct WindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.backgroundColor = NSColor(Night.background)
            view.window?.isMovableByWindowBackground = true
            view.window?.collectionBehavior.insert(.fullScreenPrimary)
            view.window?.setFrameAutosaveName("UniversityAfterDark.main")
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}

struct RootView: View {
    @ObservedObject var vm: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            CinematicBackground(animated: !vm.reducedMotion && vm.settings.animationIntensity > 0, gold: vm.settings.mode == .nuclear)
            Group {
                switch vm.screen {
                case .intro: IntroView(vm: vm)
                case .welcome: WelcomeView(vm: vm)
                case .players: PlayerSetupView(vm: vm, inSession: false)
                case .configuration: ConfigurationView(vm: vm)
                case .game: GameView(vm: vm)
                case .end: EndGameView(vm: vm)
                }
            }.transition(.opacity)
                .accessibilityHidden(vm.voteOpen || vm.exhaustion)
                .allowsHitTesting(!vm.voteOpen && !vm.exhaustion)
            if vm.exhaustion { exhaustionOverlay }
            if vm.voteOpen { VotingView(vm: vm) }
            NuclearAudioPulse(manager: vm.music, reducedMotion: vm.reducedMotion)
        }
        .foregroundStyle(Night.text)
        .background(KeyMonitor { vm.handleKey($0) })
        .task { vm.music.activate(context: vm.soundtrackCategory); vm.music.suspend(scenePhase != .active) }
        .onChange(of: vm.soundtrackCategory) { _, category in vm.music.follow(category) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in vm.stopAudio() }
        .onDisappear { vm.stopAudio() }
        .sheet(item: $vm.modal) { modal in
            switch modal {
            case .rules: RulesView(vm: vm)
            case .settings: SettingsView(vm: vm)
            case .statistics: StatisticsView(vm: vm)
            case .players: ModalShell(title: "The guest list", subtitle: "The night is better together", dismiss: { vm.modal = nil }) { PlayerEditor(vm: vm, inSession: true) }
            case .custom: CustomQuestionsView(vm: vm)
            }
        }
        .onChange(of: vm.modal) { _, modal in
            if modal != nil { vm.timer.pause(at: ProcessInfo.processInfo.systemUptime) }
        }
        .onChange(of: scenePhase) { _, phase in
            vm.music.suspend(phase != .active)
            if phase != .active { vm.timer.pause(at: ProcessInfo.processInfo.systemUptime); vm.votePrivacyCover = true; vm.persist() }
        }
        .alert("A note from the night", isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })) {
            Button("Understood") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
        .confirmationDialog("End this night?", isPresented: $vm.confirmEnd, titleVisibility: .visible) {
            Button("End the night") { vm.end() }
        } message: { Text("Your session statistics will be saved. You can start a new night afterward.") }
        .confirmationDialog("Reset this session?", isPresented: $vm.confirmReset, titleVisibility: .visible) {
            Button("Reset session", role: .destructive) { vm.resetSession() }
        } message: { Text("This clears session progress and question history. Players, settings, and custom questions stay saved.") }
    }
    private var exhaustionOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 23) {
                Eyebrow(text: "Every secret has its limit", color: Night.gold)
                Text("You've seen this pool.").font(Night.serif(40))
                Text("Every available \(vm.pendingType.rawValue) in this selection has been drawn.\nReset only this pool, or explore another part of the night.")
                    .font(.system(size: 14)).foregroundStyle(Night.muted).multilineTextAlignment(.center)
                HStack {
                    NightButton(title: "Reset this pool", action: vm.resetPool)
                        .disabled(vm.session?.pool(type: vm.pendingType, bank: vm.allQuestions, replacing: vm.replacingPool).isEmpty ?? true)
                    NightButton(title: "Change intensity / mode", primary: false) { vm.exhaustion = false; vm.modal = .settings }
                }
                Button("Return to the room") { vm.exhaustion = false }.buttonStyle(.plain).foregroundStyle(Night.muted)
            }.padding(50).background(Night.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Night.border)).padding(40)
        }
    }
}

/// A local event monitor keeps single-letter shortcuts away from all native text editors.
private struct KeyMonitor: NSViewRepresentable {
    var action: (String) -> Void
    final class Coordinator {
        var monitor: Any?
        var action: (String) -> Void
        init(action: @escaping (String) -> Void) { self.action = action }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  !(NSApp.keyWindow?.firstResponder is NSTextView), !(NSApp.keyWindow?.firstResponder is NSTextField),
                  NSApp.modalWindow == nil else { return event }
            let key = event.keyCode == 53 ? "escape" : (event.charactersIgnoringModifiers ?? "").lowercased()
            guard ["t", "d", "s", "n", "f", " ", "escape"].contains(key) else { return event }
            guard !event.isARepeat else { return nil }
            coordinator?.action(key)
            return nil
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.action = action }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor); coordinator.monitor = nil }
    }
}
