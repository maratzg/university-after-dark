import SwiftUI

struct MusicQuickControls: View {
    @ObservedObject var manager: MusicManager
    @State private var expanded = false
    var body: some View {
        HStack(spacing: 1) {
            IconButton(symbol: manager.preferences.wantsPlayback ? "pause.fill" : "play.fill", label: manager.preferences.wantsPlayback ? "Pause music" : "Play music", action: manager.togglePlayback)
            Button { expanded.toggle() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "waveform").font(.system(size: 13)).foregroundStyle(manager.preferences.allMuted ? Night.muted : Night.gold)
                    Image(systemName: "chevron.down").font(.system(size: 7)).foregroundStyle(Night.muted)
                }.frame(height: 36).padding(.horizontal, 7)
            }.buttonStyle(.plain).help("Soundtrack and audio controls").accessibilityLabel("Open music controls")
                .popover(isPresented: $expanded, arrowEdge: .bottom) { MusicControlPanel(manager: manager).padding(24).frame(width: 410).background(Night.surface).preferredColorScheme(.dark) }
            IconButton(symbol: manager.preferences.allMuted ? "speaker.slash.fill" : "speaker.wave.2", label: manager.preferences.allMuted ? "Unmute all audio" : "Mute all audio immediately", action: manager.toggleAllMute)
        }.padding(.horizontal, 5).background(Night.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Night.border.opacity(0.7)))
            .onChange(of: expanded) { _, value in manager.controlsPresented = value }
            .onChange(of: manager.controlsPresented) { _, value in if !value { expanded = false } }
            .onDisappear { if expanded { manager.controlsPresented = false } }
    }
}

struct MusicControlPanel: View {
    @ObservedObject var manager: MusicManager
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Eyebrow(text: "The sound of the night", color: Night.gold)
                Spacer()
                Circle().fill(manager.isPlaying && !manager.preferences.allMuted && !manager.preferences.musicMuted ? Night.crimson : Night.muted).frame(width: 5, height: 5)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(manager.currentTrack?.title ?? "After Hours").font(Night.serif(27)).fixedSize(horizontal: false, vertical: true)
                Text("\(manager.currentTrack?.category.context ?? manager.desiredCategory.context)  /  \(manager.currentTrack?.category.title ?? manager.desiredCategory.title)")
                    .font(Night.label(9)).foregroundStyle(Night.gold)
                Text(manager.statusLabel).font(.system(size: 11)).foregroundStyle(Night.muted)
            }
            HStack(spacing: 10) {
                NightButton(title: manager.preferences.wantsPlayback ? "Pause" : "Play", symbol: manager.preferences.wantsPlayback ? "pause.fill" : "play.fill", compact: true, action: manager.togglePlayback)
                IconButton(symbol: "forward.end.fill", label: "Next soundtrack", action: manager.nextTrack).disabled(!manager.canAdvance)
                IconButton(symbol: manager.preferences.musicMuted ? "speaker.slash" : "music.note", label: manager.preferences.musicMuted ? "Unmute music" : "Mute music only", action: manager.toggleMusicMute)
                Spacer()
                IconButton(symbol: manager.preferences.allMuted ? "speaker.slash.fill" : "speaker.wave.2", label: manager.preferences.allMuted ? "Unmute all audio" : "Mute all audio immediately", action: manager.toggleAllMute)
            }
            AudioVolumeRow(manager: manager, title: "Music", keyPath: \.musicVolume)
            AudioVolumeRow(manager: manager, title: "Effects", keyPath: \.effectsVolume)
            Hairline()
            Toggle("Automatic soundtrack switching", isOn: preference(\.automaticSwitching)).font(.system(size: 12))
            Toggle("Sound effects", isOn: preference(\.effectsEnabled)).font(.system(size: 12))
            Picker("Soundtrack", selection: Binding(get: { manager.selectedCategory }, set: manager.selectCategory)) {
                ForEach(SoundtrackCategory.allCases) { Text("\($0.context) · \($0.title)").tag($0) }
            }.font(.system(size: 12))
            Text("Choosing a soundtrack manually holds it across rounds. Turn Automatic back on to follow the game. Music pauses while the app is inactive.")
                .font(.system(size: 10)).foregroundStyle(Night.muted).lineSpacing(4)
            if let notice = manager.notice {
                Label(notice, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Night.gold).fixedSize(horizontal: false, vertical: true)
            }
            if manager.preferences.allMuted { Text("ALL AUDIO MUTED  ·  ⌘⇧M TO RESTORE").font(Night.label(8)).foregroundStyle(Night.bright).tracking(1) }
        }.foregroundStyle(Night.text).tint(Night.crimson).toggleStyle(.switch)
    }
    private func preference<T>(_ path: WritableKeyPath<AudioPreferences, T>) -> Binding<T> {
        Binding(get: { manager.preferences[keyPath: path] }, set: { value in manager.updatePreferences { $0[keyPath: path] = value } })
    }
}

private struct AudioVolumeRow: View {
    @ObservedObject var manager: MusicManager
    var title: String
    var keyPath: WritableKeyPath<AudioPreferences, Float>
    var body: some View {
        HStack(spacing: 14) {
            Text(title).font(.system(size: 12)).frame(width: 42, alignment: .leading)
            Slider(value: Binding(get: { Double(manager.preferences[keyPath: keyPath]) }, set: { value in manager.updatePreferences { $0[keyPath: keyPath] = Float(value) } }), in: 0...1)
                .accessibilityLabel("\(title) volume")
            Text("\(Int(manager.preferences[keyPath: keyPath] * 100))%").font(Night.label(9)).monospacedDigit().foregroundStyle(Night.muted).frame(width: 35, alignment: .trailing)
        }
    }
}

struct NuclearAudioPulse: View {
    @ObservedObject var manager: MusicManager
    var reducedMotion: Bool
    @State private var opacity = 0.0
    var body: some View {
        RadialGradient(colors: [Night.gold.opacity(0.16), Night.crimson.opacity(0.12), .clear], center: .center, startRadius: 60, endRadius: 800)
            .opacity(opacity).allowsHitTesting(false).accessibilityHidden(true)
            .task(id: manager.nuclearImpact) {
                guard manager.nuclearImpact > 0, !reducedMotion else { opacity = 0; return }
                opacity = 1
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.7)) { opacity = 0 }
            }
    }
}
