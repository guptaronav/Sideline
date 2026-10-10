import SwiftUI
import UIKit

// MARK: - Color

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// Sport look: white field, black ink, electric blue for "your normal", orange only for "act now".
enum Palette {
    static let paper  = Color(light: 0xFFFFFF, dark: 0x0B0B0D)
    static let card   = Color(light: 0xF3F3F1, dark: 0x17171A)
    static let ink    = Color(light: 0x0A0A0B, dark: 0xF4F4F5)
    static let muted  = Color(light: 0x6B6B70, dark: 0x9A9AA0)
    static let rule   = Color(light: 0xE2E2E4, dark: 0x2A2A2E)
    static let flag   = Color(light: 0xFF4F1F, dark: 0xFF6A3D)
    static let steady = Color(light: 0x1446FF, dark: 0x5B7CFF)

    // Brand surfaces (sign-in, team headers, test screens): deep navy, white ink.
    static let brand       = Color(hex: 0x0B1B3A)
    static let brandRaised = Color(hex: 0x14284F)
    static let brandInk    = Color.white
    static let brandMuted  = Color.white.opacity(0.7)

    // The capture viewport is always dark, in both appearances.
    static let viewport     = Color(hex: 0x0E100F)
    static let viewportInk  = Color(hex: 0xE9E6DE)
    static let viewportGaze = Color(hex: 0x7FD1B4)
}

// MARK: - Type

enum Typeface {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size * 0.92, weight: .bold)
    }
    /// The one big number on a screen (step, score). Used sparingly.
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static let body = Font.system(size: 16)
    static let caption = Font.system(size: 13)
}

enum Space {
    static let gutter: CGFloat = 20
    static let section: CGFloat = 32
}

// MARK: - Components

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.muted

    init(_ text: String, color: Color = Palette.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(color)
    }
}

/// Section divider: a hairline.
struct HashRule: View {
    var body: some View {
        Rectangle().fill(Palette.rule).frame(height: 1).accessibilityHidden(true)
    }
}

/// Icon theme, locked: SF Symbols only, semibold weight.
/// Things (tests, steps, roles) sit in a colored rounded tile; details (time, counts, dates) get a small inline glyph.
enum Icon {
    static let time = "clock"
    static let date = "calendar"
    static let steps = "stairs"
    static let team = "person.3.fill"
    static let clinician = "stethoscope"
    static let alert = "exclamationmark.triangle.fill"
    static let check = "checkmark.circle.fill"
    static let baseline = "scope"
}

struct IconTile: View {
    let symbol: String
    var tint: Color = Palette.steady
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

struct IconLabel: View {
    let symbol: String
    let text: String
    var color: Color = Palette.muted

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(color)
    }
}

/// Each test has its own color, carried from the list into the capture screen and the result.
extension GraphTest {
    var tint: Color {
        switch self {
        case .lightResponse:       Color(hex: 0xF5A300)
        case .followTheDot:        Color(hex: 0x00A8E0)
        case .holdAndLook:         Color(hex: 0x6E56F0)
        case .dynamicVisualAcuity: Color(hex: 0x1FB86A)
        case .closeUpEyePhoto:     Color(hex: 0xF0487E)
        }
    }

    var symbol: String {
        switch self {
        case .lightResponse:       "sun.max.fill"
        case .followTheDot:        "smallcircle.filled.circle"
        case .holdAndLook:         "scope"
        case .dynamicVisualAcuity: "arrow.left.and.right"
        case .closeUpEyePhoto:     "camera.aperture"
        }
    }
}

struct Tag: View {
    let text: String
    let color: Color
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.12), in: Capsule())
    }
}

struct SolidButton: ButtonStyle {
    var tint: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func panel() -> some View {
        self
            .padding(18)
            .background(Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
