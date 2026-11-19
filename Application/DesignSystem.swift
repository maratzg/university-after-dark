import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

enum Night {
    static let background = Color(hex: 0x080809)
    static let surface = Color(hex: 0x111114)
    static let card = Color(hex: 0x19191E)
    static let crimson = Color(hex: 0xC11235)
    static let bright = Color(hex: 0xFF234F)
    static let burgundy = Color(hex: 0x540D22)
    static let gold = Color(hex: 0xC9A66B)
    static let text = Color(hex: 0xF5F1F2)
    static let muted = Color(hex: 0x97939B)
    static let border = Color(hex: 0x343039)
    static func serif(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func label(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

struct Eyebrow: View {
    var text: String
    var color: Color = Night.muted
    var body: some View { Text(text.uppercased()).font(Night.label()).tracking(2.5).foregroundStyle(color) }
}

struct NightButton: View {
    var title: String
    var symbol: String? = nil
    var primary = true
    var gold = false
    var compact = false
    var action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title.uppercased()).font(.system(size: compact ? 10 : 11, weight: .semibold)).tracking(1.8)
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .medium)) }
            }
            .padding(.horizontal, compact ? 16 : 25).padding(.vertical, compact ? 12 : 18)
            .foregroundStyle(primary ? (gold ? Night.background : Night.text) : Night.text)
            .background(primary ? (gold ? Night.gold : Night.crimson) : Night.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(primary ? Color.white.opacity(0.08) : Night.border, lineWidth: 1))
            .brightness(hovered && enabled ? 0.06 : 0).opacity(enabled ? 1 : 0.38)
            .shadow(color: primary && hovered ? (gold ? Night.gold : Night.crimson).opacity(0.25) : .clear, radius: 20)
        }.buttonStyle(.plain).onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hovered)
    }
}

struct IconButton: View {
    var symbol: String
    var label: String
    var action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 15)).frame(width: 36, height: 36)
            .foregroundStyle(hovered ? Night.text : Night.muted).background(hovered ? Night.card : .clear, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label).onHover { hovered = $0 }
    }
}

struct Hairline: View { var body: some View { Rectangle().fill(Night.border.opacity(0.65)).frame(height: 1) } }

struct PlayerAvatar: View {
    var player: Player
    var index: Int = 0
    var size: CGFloat = 38
    var active = false
    private var color: Color { [Night.crimson, Night.gold, Color(hex: 0x9E7185), Color(hex: 0x79738E)][abs(index) % 4] }
    var body: some View {
        Text(player.initials.isEmpty ? "·" : player.initials).font(.system(size: size * 0.31, weight: .semibold))
            .foregroundStyle(active ? Night.text : color)
            .frame(width: size, height: size)
            .background(active ? Night.crimson : color.opacity(0.1), in: Circle())
            .overlay(Circle().strokeBorder(active ? Night.bright.opacity(0.7) : color.opacity(0.25), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct CinematicBackground: View {
    var animated: Bool = true
    var gold = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animated || reduceMotion)) { context in
                let time = animated && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0
                let drift = CGFloat(sin(time * 0.16)) * 30
                ZStack {
                    Night.background
                    Ellipse().fill(Night.crimson.opacity(0.16)).frame(width: geometry.size.width * 0.7, height: 450)
                        .blur(radius: 110).offset(x: geometry.size.width * 0.25 + drift, y: -geometry.size.height * 0.1)
                    Ellipse().fill((gold ? Night.gold : Night.burgundy).opacity(0.12)).frame(width: 550, height: 450)
                        .blur(radius: 120).offset(x: -geometry.size.width * 0.4, y: geometry.size.height * 0.45)
                    Canvas { ctx, size in
                        for index in 0..<95 {
                            let x = CGFloat((index * 193 + 53) % 997) / 997 * size.width
                            let y = CGFloat((index * 277 + 91) % 991) / 991 * size.height
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.07)))
                        }
                    }
                    LinearGradient(colors: [.clear, Night.background.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BrandMark: View {
    var small = false
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).strokeBorder(Night.crimson.opacity(0.75)).frame(width: 28, height: 32)
                Text("U").font(.system(size: 21, weight: .medium, design: .serif)).foregroundStyle(Night.bright)
                Rectangle().fill(Night.background).frame(width: 18, height: 2).offset(y: 6)
            }
            if !small {
                VStack(alignment: .leading, spacing: 3) {
                    Text("UNIVERSITY").font(.system(size: 10, weight: .bold)).tracking(3)
                    Text("AFTER DARK").font(.system(size: 8, weight: .medium)).tracking(3.7).foregroundStyle(Night.muted)
                }
            }
        }
    }
}

struct ModalShell<Content: View>: View {
    var title: String
    var subtitle: String
    var dismiss: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: subtitle, color: Night.gold)
                    Text(title).font(Night.serif(36))
                }
                Spacer()
                IconButton(symbol: "xmark", label: "Close", action: dismiss)
            }.padding(30)
            Hairline()
            ScrollView { content.padding(30).frame(maxWidth: .infinity, alignment: .leading) }
        }.frame(width: 820, height: 690).background(Night.surface).foregroundStyle(Night.text).preferredColorScheme(.dark)
    }
}

struct EmptyState: View {
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Night.gold)
            Text(title).font(Night.serif(30))
            Text(message).font(.system(size: 13)).foregroundStyle(Night.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(40)
    }
}
