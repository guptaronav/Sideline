import SwiftUI

/// Guided sideline check. The capture is simulated: no camera is used and every value is scripted.
struct CheckView: View {
    private enum Phase { case intro, pursuit, light, result }

    private static let pursuitSeconds = 6.0
    private static let lightSeconds = 4.5

    let athleteID: Int

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .intro
    @State private var startedAt = Date()

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch phase {
            case .intro:
                intro
            case .pursuit:
                CaptureFrame(
                    step: "Step 1 of 2 · Smooth pursuit",
                    instruction: "Follow the dot with your eyes only.",
                    duration: Self.pursuitSeconds,
                    startedAt: startedAt,
                    readouts: { t in [("Pursuit gain", String(format: "%.2f", 0.74 + 0.02 * sin(t * 3)))] }
                ) { t in PursuitViewport(t: t) }
            case .light:
                CaptureFrame(
                    step: "Step 2 of 2 · Light reflex",
                    instruction: "Look straight ahead. A light will flash once.",
                    duration: Self.lightSeconds,
                    startedAt: startedAt,
                    readouts: { t in [("Pupil diameter", String(format: "%.1f mm", LightViewport.pupilFraction(t) * 11.7))] }
                ) { t in LightViewport(t: t) }
            case .result:
                ResultView(athleteID: athleteID) { dismiss() }
            }
        }
        .task(id: phase) { await advance() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Eyebrow("Sideline check")
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
            Text("Hold the phone at arm's length, level with the athlete's eyes.")
                .font(Typeface.display(30))
                .foregroundStyle(Palette.ink)
            HashRule()
            VStack(alignment: .leading, spacing: 14) {
                instruction("1", "The athlete follows a moving dot.")
                instruction("2", "One light flash tests the pupil.")
                instruction("3", "Results are compared with their own baseline.")
            }
            Spacer()
            Text("Simulated capture for demonstration. No camera is used.")
                .font(Typeface.caption)
                .foregroundStyle(Palette.muted)
            Button("Begin") {
                startedAt = .now
                phase = .pursuit
            }
            .buttonStyle(SolidButton())
        }
        .padding(Space.gutter)
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(number).font(Typeface.mono(15, weight: .bold)).foregroundStyle(Palette.flag)
            Text(text).font(Typeface.body).foregroundStyle(Palette.ink)
        }
    }

    private func advance() async {
        switch phase {
        case .pursuit:
            try? await Task.sleep(for: .seconds(Self.pursuitSeconds))
            guard !Task.isCancelled else { return }
            startedAt = .now
            phase = .light
        case .light:
            try? await Task.sleep(for: .seconds(Self.lightSeconds))
            guard !Task.isCancelled else { return }
            store.flag(athleteID)
            phase = .result
        default:
            break
        }
    }
}

// MARK: - Capture frame

private struct CaptureFrame<Viewport: View>: View {
    let step: String
    let instruction: String
    let duration: Double
    let startedAt: Date
    let readouts: (Double) -> [(String, String)]
    let viewport: (Double) -> Viewport

    init(step: String, instruction: String, duration: Double, startedAt: Date,
         readouts: @escaping (Double) -> [(String, String)],
         @ViewBuilder viewport: @escaping (Double) -> Viewport) {
        self.step = step
        self.instruction = instruction
        self.duration = duration
        self.startedAt = startedAt
        self.readouts = readouts
        self.viewport = viewport
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = min(max(timeline.date.timeIntervalSince(startedAt), 0), duration)
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow(step, color: Palette.flag)
                Text(instruction)
                    .font(Typeface.display(26))
                    .foregroundStyle(Palette.ink)
                    .frame(minHeight: 64, alignment: .topLeading)

                viewport(t)
                    .aspectRatio(0.86, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(alignment: .topLeading) {
                        Text("SIMULATED CAPTURE")
                            .font(Typeface.mono(10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.viewportInk.opacity(0.55))
                            .padding(10)
                    }

                HStack(alignment: .firstTextBaseline) {
                    ForEach(Array(readouts(t).enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(item.0)
                            Text(item.1).font(Typeface.mono(24, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                    }
                    Spacer()
                    Text(String(format: "%.0f s", max(duration - t, 0).rounded(.up)))
                        .font(Typeface.mono(15))
                        .foregroundStyle(Palette.muted)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.rule)
                        Rectangle().fill(Palette.ink).frame(width: geo.size.width * t / duration)
                    }
                }
                .frame(height: 3)
                Spacer(minLength: 0)
            }
            .padding(Space.gutter)
        }
    }
}

// MARK: - Viewports

private struct PursuitViewport: View {
    let t: Double

    /// Unit-square position of the target at time t.
    static func target(_ t: Double) -> CGPoint {
        CGPoint(x: 0.5 + 0.36 * sin(t * 2.1), y: 0.5 + 0.2 * sin(t * 4.2 + 0.6))
    }

    /// The gaze trails the target and jitters slightly, as a tired tracker would.
    static func gaze(_ t: Double) -> CGPoint {
        let p = target(t - 0.11)
        return CGPoint(x: p.x + 0.006 * sin(t * 23), y: p.y + 0.006 * cos(t * 19))
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.viewport))
            drawGrid(&ctx, size)

            let trailLength = 30
            for k in (0..<trailLength).reversed() {
                let p = Self.gaze(t - Double(k) * 0.025)
                let alpha = 0.7 * (1 - Double(k) / Double(trailLength))
                let r = 3.5 * (1 - Double(k) / Double(trailLength * 2))
                ctx.fill(circle(p, r, size), with: .color(Palette.viewportGaze.opacity(alpha)))
            }

            let target = Self.target(t)
            ctx.stroke(circle(target, 13, size), with: .color(Palette.viewportInk), lineWidth: 1.5)
            ctx.fill(circle(target, 3, size), with: .color(Palette.viewportInk))
            drawBrackets(&ctx, size)
        }
        .accessibilityHidden(true)
    }

    private func circle(_ unit: CGPoint, _ radius: CGFloat, _ size: CGSize) -> Path {
        let c = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
        return Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var path = Path()
        for i in 1..<8 {
            let x = size.width * CGFloat(i) / 8
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for i in 1..<10 {
            let y = size.height * CGFloat(i) / 10
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path, with: .color(Palette.viewportInk.opacity(0.06)), lineWidth: 1)
    }
}

private func drawBrackets(_ ctx: inout GraphicsContext, _ size: CGSize) {
    let inset: CGFloat = 14, arm: CGFloat = 18
    var p = Path()
    for (x, dx) in [(inset, arm), (size.width - inset, -arm)] {
        for (y, dy) in [(inset, arm), (size.height - inset, -arm)] {
            p.move(to: CGPoint(x: x + dx, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy))
        }
    }
    ctx.stroke(p, with: .color(Palette.viewportInk.opacity(0.5)), lineWidth: 1.5)
}

struct LightViewport: View {
    let t: Double

    private static let flashAt = 1.4
    private static let latency = 0.29

    /// Pupil diameter as a fraction of iris diameter: constricts after the flash, then slowly recovers.
    static func pupilFraction(_ t: Double) -> Double {
        let onset = flashAt + latency
        guard t > onset else { return 0.56 }
        let constrict = 0.22 * (1 - exp(-(t - onset) * 5))
        let recover = t > 3.0 ? 0.08 * (1 - exp(-(t - 3.0) * 1.2)) : 0
        return 0.56 - constrict + recover
    }

    private var flashOpacity: Double {
        max(0, 1 - abs(t - (Self.flashAt + 0.1)) / 0.12) * 0.75
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.viewport))

            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let irisR = min(size.width, size.height) * 0.34
            let pupilR = irisR * Self.pupilFraction(t)

            var fibers = Path()
            for i in 0..<84 {
                let a = Double(i) / 84 * 2 * .pi
                let inner = pupilR + 2, outer = irisR - 2
                fibers.move(to: CGPoint(x: c.x + inner * cos(a), y: c.y + inner * sin(a)))
                fibers.addLine(to: CGPoint(x: c.x + outer * cos(a), y: c.y + outer * sin(a)))
            }
            ctx.stroke(fibers, with: .color(Palette.viewportGaze.opacity(0.32)), lineWidth: 1)

            ctx.stroke(ring(c, irisR), with: .color(Palette.viewportInk.opacity(0.8)), lineWidth: 1.5)
            ctx.fill(ring(c, pupilR), with: .color(.black))
            ctx.stroke(ring(c, pupilR), with: .color(Palette.viewportInk.opacity(0.45)), lineWidth: 1)

            drawBrackets(&ctx, size)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(flashOpacity)))
        }
        .accessibilityHidden(true)
    }

    private func ring(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
