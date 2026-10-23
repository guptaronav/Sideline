import SwiftUI

/// The check. Which tests run, in what order, their names and real durations all come from the graph (Graph.swift).
/// Capture is simulated in this demo: no camera is used, every value is scripted, and each test is shortened.
struct CheckView: View {
    private enum Phase: Equatable { case intro, position, next(Int), test(Int), retake(Int), result }

    /// Demo length per test. The real duration from the catalog is shown on screen.
    private static let demoSeconds = 5.0
    /// The retake moment shows once per app launch, so a repeat demo isn't slowed down.
    private static var retakeShown = false

    let athleteID: Int
    var kind: CheckKind = .sideline

    @Environment(Store.self) private var store
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .intro
    @State private var elapsed = 0.0
    @State private var runningSince: Date?
    @State private var paused = false
    @State private var retaking = false
    @State private var outcome: DailyOutcome?

    private var tests: [GraphTest] { kind.tests }
    private var athlete: Athlete? { store.athlete(athleteID) }

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch phase {
            case .intro:
                intro
            case .position:
                PositionView(
                    kind: kind,
                    simulationCameraAssetName: athlete?.firstName == "Priya" ? "position-priya-camera" : nil
                )
            case .next(let i):
                NextUpView(test: tests[i], index: i, count: tests.count) { start(i) }
            case .test(let i) where tests[i].runsLive:
                // Real camera test on a phone with face tracking; the scripted screen runs everywhere else.
                LiveTestScreen(test: tests[i], index: i, count: tests.count,
                               onDone: { completeTest(i) }, onEnd: { dismiss() })
            case .test(let i):
                TestScreen(test: tests[i], index: i, count: tests.count, kind: kind,
                           progress: { now in progress(at: now) }, duration: Self.demoSeconds,
                           losesTracking: willRetake(i), paused: paused,
                           onPause: pause, onResume: resume, onEnd: { dismiss() })
            case .retake(let i):
                RetakeView(test: tests[i]) { retaking = true; start(i) }
            case .result:
                result
            }
        }
        .task(id: phase) { await advance() }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(kind == .sideline ? "Sideline check · \(athlete?.name ?? "")" : kind == .baseline ? "Your baseline" : "Your comeback")
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
            Text(title)
                .font(Typeface.display(32))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(Typeface.body)
                .foregroundStyle(Palette.muted)
            HashRule()
            VStack(spacing: 0) {
                ForEach(Array(tests.enumerated()), id: \.element) { i, test in
                    HStack(alignment: .center, spacing: 12) {
                        IconTile(symbol: test.symbol, tint: test.tint, size: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(test.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(test.measures + (test.isScored ? "" : " · practice for now"))
                                .font(Typeface.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        IconLabel(symbol: Icon.time, text: "\(test.seconds) s")
                    }
                    .padding(.vertical, 10)
                    Rectangle().fill(Palette.rule).frame(height: 1)
                }
            }
            Spacer(minLength: 0)
            Button(kind == .sideline ? "Begin check" : "Start") {
                LiveMeasurements.shared.clear()
                phase = .position
            }
            .buttonStyle(SolidButton())
        }
        .padding(Space.gutter)
    }

    private var title: String {
        switch kind {
        case .sideline: "Hold the phone at arm's length, screen toward \(athlete?.firstName ?? "the athlete")."
        case .baseline: "Set your normal."
        case .daily:    "Today's check."
        }
    }

    private var subtitle: String {
        let minutes = kind.minutes
        switch kind {
        case .sideline: return "\(tests.count) tests, about \(minutes) minutes. You won't see the screen: a tone and a buzz mark the start, halfway and the end."
        case .baseline: return "\(tests.count) short tests, about \(minutes) minutes. Do your best: this is what your eyes do on a good day."
        case .daily:    return "\(tests.count) tests, about \(minutes) minutes. Back at your normal moves you up a step."
        }
    }

    // MARK: Flow

    /// Hold & Look loses the eyes partway through, once, on a daily check: it shows the retake path.
    private func willRetake(_ i: Int) -> Bool {
        kind == .daily && tests[i] == .holdAndLook && !retaking && !Self.retakeShown
    }

    private func start(_ i: Int) {
        elapsed = 0
        paused = false
        runningSince = .now
        phase = .test(i)
    }

    private func progress(at now: Date) -> Double {
        min(elapsed + (runningSince.map { now.timeIntervalSince($0) } ?? 0), Self.demoSeconds)
    }

    private func pause() {
        elapsed = progress(at: .now)
        runningSince = nil
        paused = true
    }

    /// A paused test restarts: a partial recording can't be scored.
    private func resume() {
        elapsed = 0
        runningSince = .now
        paused = false
    }

    private func advance() async {
        switch phase {
        case .position:
            try? await Task.sleep(for: .seconds(PositionView.length))
            guard !Task.isCancelled else { return }
            start(0)
        case .test(let i):
            guard !tests[i].runsLive else { return }   // a live test advances when its recording ends
            while progress(at: .now) < Self.demoSeconds {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            if willRetake(i) {
                Self.retakeShown = true
                phase = .retake(i)
            } else {
                completeTest(i)
            }
        default:
            break
        }
    }

    private func completeTest(_ i: Int) {
        if i + 1 < tests.count {
            phase = .next(i + 1)
        } else {
            finish()
            phase = .result
        }
    }

    private func finish() {
        let measured = LiveMeasurements.shared.values
        LiveMeasurements.shared.clear()
        switch kind {
        case .sideline:
            if measured.isEmpty { store.flag(athleteID) } else { store.recordSidelineCheck(athleteID, measured: measured) }
        case .baseline:
            store.recordBaseline(athleteID, measured: measured)
            if let a = athlete { Task { await HealthPush.baseline(a, session: session) } }
        case .daily:
            outcome = store.recordDailyCheck(athleteID, measured: measured)
            if let a = athlete, let o = outcome { Task { await HealthPush.daily(a, outcome: o, decision: o.summary, session: session) } }
        }
    }

    @ViewBuilder
    private var result: some View {
        switch kind {
        case .sideline: ResultView(athleteID: athleteID) { dismiss() }
        case .baseline: BaselineSavedView(tests: tests) { dismiss() }
        case .daily:
            if let outcome { DailyResultView(outcome: outcome, specs: athlete?.biomarkers ?? BiomarkerSpec.tracked) { dismiss() } }
        }
    }
}

// MARK: - Get in position

/// A camera-style frame: the face outline fills as each check passes, then a 3-2-1 countdown.
private struct PositionView: View {
    let kind: CheckKind
    let simulationCameraAssetName: String?
    @State private var start = Date()

    private let sequence = PositionSequence()
    static var length: Double { PositionSequence.length }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            let state = sequence.state(at: t)
            ZStack {
                GeometryReader { geo in
                    let guideWidth = min(geo.size.width * 0.84, 360)
                    let guideHeight = guideWidth * PositionComposition.faceGuideHeightToWidth
                    let guideCenterY = geo.size.height * 0.42

                    ZStack {
                        if FaceTrackingCamera.isSupported {
                            FaceTrackingCamera(meshOpacity: state.meshOpacity)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else if let simulationCameraAssetName,
                                  let image = UIImage(named: simulationCameraAssetName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .offset(y: geo.size.height * 0.07)
                                .clipped()
                        } else {
                            Palette.viewport
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: guideWidth * 0.72)
                                .foregroundStyle(Palette.viewportInk.opacity(0.12))
                        }

                        LinearGradient(
                            colors: [.black.opacity(0.54), .clear, .clear, .black.opacity(0.68)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        if !FaceTrackingCamera.isSupported {
                            FallbackFaceMesh()
                                .frame(width: guideWidth * 0.95, height: guideHeight * 0.96)
                                .position(x: geo.size.width / 2, y: guideCenterY)
                            .opacity(state.meshOpacity)
                        }

                        Ellipse()
                            .stroke(
                                state.isReady ? Palette.steady : Color.white.opacity(0.86),
                                style: StrokeStyle(
                                    lineWidth: state.isReady ? 3 : 1.5,
                                    dash: state.isReady ? [] : [8, 7]
                                )
                            )
                            .frame(width: guideWidth, height: guideHeight)
                            .position(x: geo.size.width / 2, y: guideCenterY)
                            .opacity(state.meshOpacity)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(
                        state.isReady ? "Hold still" : "Get in position",
                        color: state.isReady ? Palette.steady : .white.opacity(0.82)
                    )
                    Text(state.isReady ? "Starting in \(state.countdown)." : headline)
                        .font(Typeface.display(26))
                        .foregroundStyle(.white)
                    Spacer()
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(PositionSequence.checks.enumerated()), id: \.offset) { i, item in
                            HStack(spacing: 10) {
                                Image(systemName: i < state.completedChecks ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(i < state.completedChecks ? Palette.steady : Color.white.opacity(0.48))
                                Text(item).font(Typeface.body)
                                    .foregroundStyle(.white.opacity(i < state.completedChecks ? 1 : 0.62))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 70)
                .padding(.bottom, Space.gutter)
            }
            .background(Palette.viewport)
            .ignoresSafeArea()
        }
    }

    private var headline: String {
        kind == .sideline ? "Hold steady. Sideline says “closer” or “hold there” out loud." : "Fit your face in the outline."
    }
}

/// Simulator-only stand-in for screenshots and video. Real TrueDepth devices use
/// `ARSCNFaceGeometry` above; this dense topology mirrors its facial openings and planes.
private struct FallbackFaceMesh: View {
    var body: some View {
        Canvas { context, size in
            let rows = PositionComposition.fallbackMeshRows
            let columns = PositionComposition.fallbackMeshColumns

            func halfWidth(at y: Double) -> Double {
                let vertical = (y - 0.49) / 0.53
                let oval = pow(max(0, 1 - vertical * vertical), 0.56)
                let jaw = y > 0.62 ? 1 - (y - 0.62) * 0.42 : 1
                return 0.47 * oval * jaw
            }

            func normalizedPoint(row: Int, column: Int) -> CGPoint {
                let baseY = 0.02 + 0.96 * Double(row) / Double(rows - 1)
                let yJitter = row == 0 || row == rows - 1
                    ? 0
                    : sin(Double(row * 47 + column * 29)) * 0.007
                let y = baseY + yJitter
                let half = halfWidth(at: y)
                let baseX = 0.5 - half + (half * 2 * Double(column) / Double(columns - 1))
                let xJitter = column == 0 || column == columns - 1
                    ? 0
                    : sin(Double(row * 31 + column * 61)) * 0.012
                let x = baseX + xJitter
                return CGPoint(x: x, y: y)
            }

            func insideOpening(_ point: CGPoint) -> Bool {
                let openings: [(Double, Double, Double, Double)] = [
                    (0.33, 0.38, 0.105, 0.045),
                    (0.67, 0.38, 0.105, 0.045),
                    (0.50, 0.72, 0.155, 0.035)
                ]
                return openings.contains { cx, cy, rx, ry in
                    let dx = (Double(point.x) - cx) / rx
                    let dy = (Double(point.y) - cy) / ry
                    return dx * dx + dy * dy < 1
                }
            }

            func canvasPoint(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x * size.width, y: point.y * size.height)
            }

            func drawEdge(_ a: CGPoint, _ b: CGPoint) {
                let midpoint = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                guard !insideOpening(midpoint) else { return }
                var path = Path()
                path.move(to: canvasPoint(a))
                path.addLine(to: canvasPoint(b))
                context.stroke(path, with: .color(.white.opacity(0.70)), lineWidth: 0.65)
            }

            for row in 0..<rows {
                for column in 0..<columns {
                    let point = normalizedPoint(row: row, column: column)
                    if column + 1 < columns {
                        drawEdge(point, normalizedPoint(row: row, column: column + 1))
                    }
                    if row + 1 < rows {
                        drawEdge(point, normalizedPoint(row: row + 1, column: column))
                        if row.isMultiple(of: 2), column + 1 < columns {
                            drawEdge(point, normalizedPoint(row: row + 1, column: column + 1))
                        } else if !row.isMultiple(of: 2), column > 0 {
                            drawEdge(point, normalizedPoint(row: row + 1, column: column - 1))
                        }
                    }

                    guard !insideOpening(point) else { continue }
                    let p = canvasPoint(point)
                    let dot = CGRect(x: p.x - 0.7, y: p.y - 0.7, width: 1.4, height: 1.4)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.88)))
                }
            }

            let contours: [CGRect] = [
                CGRect(x: 0.225, y: 0.335, width: 0.21, height: 0.09),
                CGRect(x: 0.565, y: 0.335, width: 0.21, height: 0.09),
                CGRect(x: 0.345, y: 0.685, width: 0.31, height: 0.07)
            ]
            for contour in contours {
                let rect = CGRect(
                    x: contour.minX * size.width,
                    y: contour.minY * size.height,
                    width: contour.width * size.width,
                    height: contour.height * size.height
                )
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 0.9)
            }

            var nose = Path()
            nose.move(to: canvasPoint(CGPoint(x: 0.50, y: 0.40)))
            nose.addLine(to: canvasPoint(CGPoint(x: 0.43, y: 0.60)))
            nose.addLine(to: canvasPoint(CGPoint(x: 0.50, y: 0.64)))
            nose.addLine(to: canvasPoint(CGPoint(x: 0.57, y: 0.60)))
            nose.closeSubpath()
            context.stroke(nose, with: .color(.white.opacity(0.82)), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Launch with `-positionDemo` to capture the simulator fallback without tapping through the app.
struct PositionPreviewHost: View {
    var body: some View {
        PositionView(kind: .baseline, simulationCameraAssetName: "position-priya-camera")
    }
}
#endif

// MARK: - Between tests

/// A breather before each test: what's next, what to do, how long it takes.
private struct NextUpView: View {
    let test: GraphTest
    let index: Int
    let count: Int
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Palette.viewport.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("Next up · \(index + 1) of \(count)", color: test.tint)
                Spacer()
                IconTile(symbol: test.symbol, tint: test.tint, size: 64)
                Text(test.name).font(Typeface.display(32)).foregroundStyle(Palette.viewportInk)
                Text(test.instruction).font(.system(size: 18)).foregroundStyle(Palette.viewportInk.opacity(0.8))
                IconLabel(symbol: Icon.time, text: "\(test.seconds) seconds", color: Palette.viewportInk.opacity(0.6))
                Spacer()
                Button("Start", action: onStart).buttonStyle(SolidButton(tint: test.tint))
            }
            .padding(Space.gutter)
        }
    }
}

/// Shown when the camera lost the eyes during a test: one retake, then the check carries on.
private struct RetakeView: View {
    let test: GraphTest
    let onRetake: () -> Void

    var body: some View {
        ZStack {
            Palette.viewport.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("One more time", color: test.tint)
                Spacer()
                Image(systemName: "eye.slash")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Palette.viewportInk)
                Text("We lost your eyes for a few seconds.").font(Typeface.display(30)).foregroundStyle(Palette.viewportInk)
                Text("Let's redo \(test.name) so today's result is accurate. Keep the phone level and your face in the outline.")
                    .font(.system(size: 18)).foregroundStyle(Palette.viewportInk.opacity(0.8))
                IconLabel(symbol: Icon.time, text: "\(test.seconds) seconds", color: Palette.viewportInk.opacity(0.6))
                Spacer()
                Button("Redo \(test.name)", action: onRetake).buttonStyle(SolidButton(tint: test.tint))
            }
            .padding(Space.gutter)
        }
    }
}

// MARK: - One test, full screen

private struct TestScreen: View {
    let test: GraphTest
    let index: Int
    let count: Int
    let kind: CheckKind
    let progress: (Date) -> Double
    let duration: Double
    /// Script the camera losing the eyes partway through, which leads to a retake.
    let losesTracking: Bool
    let paused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = progress(tl.date)
            let lost = losesTracking && (0.5...0.8).contains(t / duration)
            ZStack {
                Palette.viewport.ignoresSafeArea()
                stimulus(t)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Eyebrow("\(index + 1) of \(count)", color: test.tint)
                        Spacer()
                        tracking(lost: lost)
                        Button(action: onPause) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.viewportInk)
                                .frame(width: 34, height: 34)
                                .background(Palette.viewportInk.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel("Pause")
                    }
                    Text(test.name)
                        .font(Typeface.display(26))
                        .foregroundStyle(Palette.viewportInk)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.viewportInk.opacity(0.18))
                            Capsule().fill(test.tint).frame(width: geo.size.width * t / duration)
                        }
                    }
                    .frame(height: 5)
                    Spacer()
                    Text(test.instruction)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.viewportInk)
                    if kind == .sideline && test.constraint == "solo-front" {
                        Text("Coach hears a tone at the start, halfway and the end.")
                            .font(Typeface.caption).foregroundStyle(Palette.viewportInk.opacity(0.55))
                    }
                }
                .padding(Space.gutter)
                if paused { pausedOverlay }
            }
        }
    }

    /// Live camera status. The rear-camera eye photo is framed by the coach, so it shows no eye tracking.
    @ViewBuilder
    private func tracking(lost: Bool) -> some View {
        if test.constraint == "solo-front" {
            HStack(spacing: 6) {
                Circle().fill(lost ? Palette.flag : Palette.steady).frame(width: 8, height: 8)
                Text(lost ? "Eyes not found" : "Eyes tracked")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.viewportInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.viewportInk.opacity(0.12), in: Capsule())
        }
    }

    private var pausedOverlay: some View {
        ZStack {
            Palette.viewport.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Paused").font(Typeface.display(30)).foregroundStyle(Palette.viewportInk)
                Text("\(test.name) starts over when you resume.")
                    .font(Typeface.body).foregroundStyle(Palette.viewportInk.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Resume", action: onResume).buttonStyle(SolidButton(tint: test.tint)).padding(.top, 8)
                Button("End check", action: onEnd)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.viewportInk.opacity(0.8))
            }
            .padding(Space.gutter)
        }
    }

    @ViewBuilder
    private func stimulus(_ t: Double) -> some View {
        switch test {
        case .lightResponse:
            // Dark, then three full-white flashes (catalog: screen dark-adapts, flashes full white 3x).
            let r = t / duration
            let on = [0.25, 0.5, 0.75].contains { r > $0 && r < $0 + 0.05 }
            Color.white.opacity(on ? 1 : 0).ignoresSafeArea()
        case .followTheDot:
            GeometryReader { geo in
                Circle().fill(Palette.viewportInk)
                    .frame(width: 18, height: 18)
                    .position(x: geo.size.width * (0.5 + 0.38 * sin(2 * .pi * 0.4 * t)), y: geo.size.height * 0.5)
            }
        case .holdAndLook:
            ZStack {
                Rectangle().fill(Palette.viewportInk.opacity(0.3)).frame(width: 60, height: 1)
                Rectangle().fill(Palette.viewportInk.opacity(0.3)).frame(width: 1, height: 60)
                Circle().fill(Palette.viewportInk).frame(width: 10, height: 10)
            }
        case .dynamicVisualAcuity:
            VStack(spacing: 40) {
                Spacer()
                Text("E")
                    .font(.system(size: max(90 - t * 10, 34), weight: .black, design: .rounded))
                    .foregroundStyle(Palette.viewportInk)
                    .rotationEffect(.degrees(Double(Int(t / 1.2) % 4) * 90))
                HStack(spacing: 10) {
                    ForEach(["arrow.left", "arrow.up", "arrow.down", "arrow.right"], id: \.self) { name in
                        Image(systemName: name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.viewportInk)
                            .frame(width: 64, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.viewportInk.opacity(0.35), lineWidth: 1))
                    }
                }
                Text("Practice for now: this test can't score yet.")
                    .font(Typeface.caption).foregroundStyle(Palette.viewportInk.opacity(0.55))
                Spacer().frame(height: 120)
            }
        case .closeUpEyePhoto:
            let frame = min(Int(t / (duration / 3)), 2)
            VStack(spacing: 14) {
                Spacer()
                ZStack {
                    Circle().stroke(Palette.viewportInk.opacity(0.8), lineWidth: 1.5).frame(width: 150, height: 150)
                    Circle().fill(Color.black).frame(width: 62, height: 62)
                    Circle().stroke(Palette.viewportInk.opacity(0.4), lineWidth: 1).frame(width: 62, height: 62)
                }
                Text(["Photo 1 of 3 · whole eye", "Photo 2 of 3 · iris", "Photo 3 of 3 · white of the eye"][frame])
                    .font(Typeface.mono(13, weight: .semibold)).foregroundStyle(Palette.viewportInk)
                Text("Rear camera · torch on")
                    .font(Typeface.caption).foregroundStyle(Palette.viewportInk.opacity(0.55))
                Spacer().frame(height: 140)
            }
        }
    }
}

// MARK: - Results

private struct BaselineSavedView: View {
    let tests: [GraphTest]
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Baseline saved", color: Palette.steady)
            Text("Your normal is saved.").font(Typeface.display(34)).foregroundStyle(Palette.ink)
            Text("One baseline covers every sport you play. If you take a hit in any of them, the check compares you with today.")
                .font(Typeface.body).foregroundStyle(Palette.muted)
            HashRule()
            ForEach(tests) { test in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.steady)
                    Text(test.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(test.isScored ? "Captured" : "Practice").font(Typeface.caption).foregroundStyle(Palette.muted)
                }
                .padding(.vertical, 4)
            }
            Spacer()
            SavedToHealth()
            Button("Done", action: onDone).buttonStyle(SolidButton())
        }
        .padding(Space.gutter)
    }
}

/// The daily result leads with the decision (step up, hold, or doctor review), then each biomarker
/// against the model's threshold and the athlete's own normal.
private struct DailyResultView: View {
    let outcome: DailyOutcome
    let specs: [BiomarkerSpec]
    let onDone: () -> Void

    private var lagging: [BiomarkerSpec] { specs.filter { !$0.isAtNormal($0.value(outcome.reading)) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow("Today's check · day \(outcome.reading.day)")
                decision
                Text("\(specs.count - lagging.count) of \(specs.count) biomarkers at your normal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
                table
                Text("Your normal is your baseline\(outcome.baselineDate.map { " from \($0)" } ?? ""). The threshold is where the concussion screen flags a value.")
                    .font(Typeface.caption).foregroundStyle(Palette.muted)
                SavedToHealth()
                Button("Done", action: onDone).buttonStyle(SolidButton())
            }
            .padding(Space.gutter)
        }
    }

    // MARK: Decision

    @ViewBuilder
    private var decision: some View {
        if outcome.sentToProvider {
            hero(number: outcome.stepAfter, color: Palette.steady,
                 title: "Your doctor has your report",
                 body: "Two checks in a row at your normal. Your doctor decides what comes next, so stay on step \(outcome.stepAfter) for now.")
        } else if outcome.clean && outcome.stepAfter > outcome.stepBefore {
            let next = ReturnStep(rawValue: outcome.stepAfter) ?? .aerobic
            hero(number: outcome.stepAfter, color: Palette.steady,
                 title: "Step \(outcome.stepAfter) unlocked",
                 body: "Start \(next.title.lowercased()) tomorrow. \(next.today)")
        } else if outcome.clean {
            hero(number: outcome.stepAfter, color: Palette.steady,
                 title: "Back at your normal",
                 body: "Stay on step \(outcome.stepAfter) until your doctor signs the next one.")
        } else {
            let names = lagging.map { $0.name.lowercased() }.joined(separator: " and ")
            hero(number: outcome.stepBefore, color: Palette.ink,
                 title: "Stay on step \(outcome.stepBefore)",
                 body: "Your \(names) is still below your normal. Rest up and check again tomorrow.")
        }
    }

    private func hero(number: Int, color: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(number)").font(Typeface.hero(72)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step \(number) of 6").font(Typeface.caption).foregroundStyle(Palette.muted)
                    Text(title).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
                }
            }
            Text(body).font(Typeface.body).foregroundStyle(Palette.ink)
        }
    }

    // MARK: Biomarkers

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Biomarker")
                Spacer()
                Text("Today")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            ForEach(specs) { spec in
                Rectangle().fill(Palette.rule).frame(height: 1)
                row(spec)
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ spec: BiomarkerSpec) -> some View {
        let v = spec.value(outcome.reading)
        let flagged = spec.isFlagged(v)
        let normal = spec.isAtNormal(v)
        return HStack(alignment: .center, spacing: 12) {
            IconTile(symbol: spec.test.symbol, tint: spec.test.tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(spec.thresholdText).font(Typeface.caption).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(spec.format(v)).font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(flagged ? Palette.flag : Palette.ink)
                Text(flagged ? "Past threshold" : normal ? "At your normal" : "Normal \(spec.format(spec.baseline))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(flagged ? Palette.flag : normal ? Palette.steady : Palette.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
