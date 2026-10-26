import SwiftUI

/// The Sideline symbol: a pupil on a sideline, broken by two opposed hash marks.
/// Built on the 100-unit grid in the design system: stem 8, hash 22×7, pupil R15, gap 5.
struct SidelineSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 100
        let ox = rect.midX - 50 * u
        let oy = rect.midY - 50 * u
        func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: ox + x0 * u, y: oy + y0 * u, width: (x1 - x0) * u, height: (y1 - y0) * u)
        }
        var path = Path()
        path.addRect(box(46, 4, 54, 30))
        path.addRect(box(46, 10, 68, 17))
        path.addRect(box(46, 70, 54, 96))
        path.addRect(box(32, 83, 54, 90))
        path.addEllipse(in: box(35, 35, 65, 65))
        return path
    }
}

/// Primary lockup. The symbol stays ink; it is never tinted flag (it would read as an alert).
/// The wordmark is Newsreader in the design system; the system serif stands in until it is bundled.
struct SidelineLockup: View {
    var size: CGFloat = 40
    var color: Color = Palette.ink

    var body: some View {
        HStack(spacing: size * 0.3) {
            SidelineSymbol()
                .fill(color)
                .frame(width: size * 1.03, height: size * 1.03)
            Text("Sideline")
                .font(Typeface.display(size))
                .tracking(-size * 0.01)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sideline")
    }
}
