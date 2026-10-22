import SwiftUI

/// "Sticker" party style: lilac background, black ink outlines, hard offset shadows.
enum Theme {
    static let sun = Color(hex: 0xB9A6FF)          // main background (lilac, "spy" mood)
    static let sunLight = Color(hex: 0xD3C7FF)     // sunburst rays
    static let ink = Color(hex: 0x141414)          // outlines, text
    static let paper = Color.white                 // card fill
    static let red = Color(hex: 0xE63946)          // primary action
    static let lime = Color(hex: 0x1FA34A)         // correct
    static let amber = Color(hex: 0xFF7A00)        // skip
    static let danger = Color(hex: 0xE63946)       // last seconds
    static let night = ink                         // kept for older call sites (text on colour)
    static let card = Color.white
    static let stroke = ink
    static let textPrimary = ink
    static let textSecondary = ink.opacity(0.62)

    static let border: CGFloat = 3
    static let shadowOffset: CGFloat = 4

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Sticker look

/// White (or coloured) card with a thick black outline and a hard offset shadow.
struct StickerBackground<S: InsettableShape>: View {
    var shape: S
    var fill: Color = Theme.card
    var pressed = false

    var body: some View {
        ZStack {
            shape.fill(Theme.ink)
                .offset(x: pressed ? 1 : Theme.shadowOffset, y: pressed ? 1 : Theme.shadowOffset)
            shape.fill(fill)
            shape.strokeBorder(Theme.ink, lineWidth: Theme.border)
        }
    }
}

extension View {
    func sticker(_ fill: Color = Theme.card, radius: CGFloat = 18, pressed: Bool = false) -> some View {
        background(StickerBackground(shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
                                     fill: fill, pressed: pressed))
    }

    func stickerCapsule(_ fill: Color = Theme.card, pressed: Bool = false) -> some View {
        background(StickerBackground(shape: Capsule(), fill: fill, pressed: pressed))
    }
}

/// Sunny background with soft rays. (Name kept so all screens pick it up.)
struct PitchBackground: View {
    var glow: Color = Theme.sun
    var showMarkings = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.sun
                if showMarkings {
                    SunRays(count: 22)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: geo.size.width * 2.2, height: geo.size.width * 2.2)
                        .position(x: geo.size.width / 2, y: geo.size.height * 1.05)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Alternating wedges radiating from the centre.
struct SunRays: Shape {
    var count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        let step = 2 * Double.pi / Double(count * 2)
        for i in 0..<count {
            let a0 = Double(i * 2) * step
            let a1 = a0 + step
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
            p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
            p.closeSubpath()
        }
        return p
    }
}

/// Big primary button (red sticker, white text).
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.red
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.title(20))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .sticker(color, radius: 16, pressed: configuration.isPressed)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(17))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .sticker(.white, radius: 16, pressed: configuration.isPressed)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Square sticker icon button (settings, back, close).
struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(StickerPressStyle())
    }
}

struct StickerPressStyle: ButtonStyle {
    var fill: Color = .white
    var radius: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sticker(fill, radius: radius, pressed: configuration.isPressed)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Localizer in the environment

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: .arabic)
}

extension EnvironmentValues {
    var t: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}
