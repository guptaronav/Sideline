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

/// One signal color (flag) and one reassurance color (steady). Everything else is paper and ink.
enum Palette {
    static let paper  = Color(light: 0xF2EFE8, dark: 0x111312)
    static let card   = Color(light: 0xFAF8F3, dark: 0x1A1D1B)
    static let ink    = Color(light: 0x16181A, dark: 0xEDEAE2)
    static let muted  = Color(light: 0x6A6E6B, dark: 0x9A9E99)
    static let rule   = Color(light: 0xD6D1C5, dark: 0x2D312E)
    static let flag   = Color(light: 0xCF4419, dark: 0xF0693A)
    static let steady = Color(light: 0x2E5B4D, dark: 0x86B8A5)

    // The capture viewport is always dark, in both appearances.
    static let viewport     = Color(hex: 0x0E100F)
    static let viewportInk  = Color(hex: 0xE9E6DE)
    static let viewportGaze = Color(hex: 0x7FD1B4)
}

// MARK: - Type

enum Typeface {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
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
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.3)
            .foregroundStyle(color)
    }
}

/// Yard-line hash marks: a long tick every fifth mark.
struct HashRule: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            var i = 0
            while x <= size.width {
                let h = i % 5 == 0 ? size.height : size.height * 0.45
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x, y: size.height - h))
                ctx.stroke(p, with: .color(Palette.rule), lineWidth: 1)
                x += 6
                i += 1
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

struct Tag: View {
    let text: String
    let color: Color
    var filled = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(filled ? Palette.paper : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(filled ? color : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: filled ? 0 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct SolidButton: ButtonStyle {
    var tint: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.ink, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func panel() -> some View {
        self
            .padding(16)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.rule, lineWidth: 1))
    }
}
