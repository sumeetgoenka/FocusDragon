import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16

    static let accent = Color(hex: "45F0D5")
    static let accentSoft = Color(hex: "2FD9C6")
    static let flame = Color(hex: "FF8A5C")
    static let electricBlue = Color(hex: "5EA7FF")

    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = scheme == .dark
            ? [Color(hex: "0B0F1A"), Color(hex: "0E1626"), Color(hex: "0D1E2F")]
            : [Color(hex: "F4F6FB"), Color(hex: "EEF2FF"), Color(hex: "F7FBFF")]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.05)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.1)
    }

    static func headerFont(_ size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size).weight(.semibold)
    }

    static func titleFont(_ size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size).weight(.bold)
    }

    static func bodyFont(_ size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size).weight(.regular)
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient(scheme)

            Circle()
                .fill(AppTheme.accent.opacity(scheme == .dark ? 0.22 : 0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: -180, y: -200)

            Circle()
                .fill(AppTheme.flame.opacity(scheme == .dark ? 0.22 : 0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: 210, y: 180)

            Circle()
                .fill(AppTheme.electricBlue.opacity(scheme == .dark ? 0.18 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 240, y: -160)
        }
        .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke(scheme), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow(scheme), radius: 18, x: 0, y: 10)
    }
}

struct AppBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(AppTheme.bodyFont(12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

struct PrimaryGlowButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.bodyFont(14))
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(
                    colors: [accent, AppTheme.accentSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: accent.opacity(configuration.isPressed ? 0.2 : 0.45), radius: configuration.isPressed ? 6 : 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.bodyFont(13))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.cardFill(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.cardStroke(scheme), lineWidth: 1)
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct PillToggleStyle: ToggleStyle {
    var onColor: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                configuration.label
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isOn ? onColor : Color.gray.opacity(0.4))
                    .frame(width: 36, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .shadow(radius: 1)
                            .offset(x: configuration.isOn ? 9 : -9)
                            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct PulsingDot: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Circle()
                .stroke(color.opacity(0.6), lineWidth: 2)
                .frame(width: 10, height: 10)
                .scaleEffect(animate ? 2.2 : 1)
                .opacity(animate ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
