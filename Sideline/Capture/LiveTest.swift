// LiveTest.swift
// Runs Light Response, Follow the Dot and Hold & Look for real on a phone with a front TrueDepth camera:
// the camera feed, the stimulus, and the ported OculoSense computers. Everything else in Sideline stays
// scripted. In the simulator, or on a phone without face tracking, the scripted test screens run instead.

import ARKit
import Combine
import SwiftUI

extension GraphTest {
    /// Whether this phone can run the test live.
    var runsLive: Bool { LiveTestRunner.isAvailable && LiveTestRunner.liveTests.contains(self) }

    /// Live recording length. Light Response and Hold & Look use the catalog duration; Follow the Dot
    /// records 20 s of its 75, which still fills the computers' 10 s windows twice.
    var liveSeconds: Double {
        switch self {
        case .followTheDot: 20
        default:            Double(seconds)
        }
    }
}

@MainActor
final class LiveTestRunner: ObservableObject {
    nonisolated static let liveTests: Set<GraphTest> = [.lightResponse, .followTheDot, .holdAndLook]
    nonisolated static var isAvailable: Bool { ARKitCapture.isSupported }

    /// Flash onsets for Light Response (OculoSense LightResponse program): 3, 7 and 11 s, 250 ms each.
    private static let flashOnsets: [Double] = [3, 7, 11]
    private static let flashDuration = 0.25

    let test: GraphTest
    let capture = ARKitCapture()

    @Published private(set) var elapsed: Double = 0
    @Published private(set) var flashOpacity: Double = 0
    /// Moving-dot position, as a fraction of the stage (Follow the Dot): x = 0.5 + 0.38·sin(2π·0.4·t).
    @Published private(set) var dot = CGPoint(x: 0.5, y: 0.5)
    @Published private(set) var finished = false

    private var timer: Timer?
    private var startedAt: Date?
    private var firedFlashes = Set<Int>()

    init(test: GraphTest) { self.test = test }

    var duration: Double { test.liveSeconds }

    func begin(stageWidthPt: CGFloat) {
        let engine = SignalEngine.shared
        engine.registerSidelineComputers()
        engine.resetAll()
        capture.emitCameraFrames = test != .followTheDot
        capture.start()
        startedAt = .now
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick(stageWidthPt: stageWidthPt) }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        capture.stop()
    }

    private func tick(stageWidthPt: CGFloat) {
        guard let startedAt, !finished else { return }
        elapsed = Date().timeIntervalSince(startedAt)

        switch test {
        case .followTheDot:
            dot = CGPoint(x: 0.5 + 0.38 * sin(2 * .pi * 0.4 * elapsed), y: 0.5)
            // Pursuit gain divides by the dot's sweep angle: use what it really subtends at this distance.
            let distance = SignalEngine.shared.values["face_distance_m"].map(Float.init) ?? 0.30
            SmoothPursuitGainV1.targetAmplitudeDeg =
                OcularCalibration.visualAngleDeg(forOffsetPt: stageWidthPt * 0.38, faceDistanceM: distance)
        case .lightResponse:
            for (k, onset) in Self.flashOnsets.enumerated() where !firedFlashes.contains(k) && elapsed >= onset {
                firedFlashes.insert(k)
                flash()
            }
        default:
            break
        }

        if elapsed >= duration { finish() }
    }

    /// Light Response flash. The stimulus events are stamped with system uptime, the same clock as
    /// ARFrame.timestamp. OculoSense stamped them with wall-clock time, so its PLR window never opened.
    private func flash() {
        flashOpacity = 1
        SignalEngine.shared.ingest(.stimulusEvent(color: "bright", isOnset: true,
                                                  timestamp: ProcessInfo.processInfo.systemUptime))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.flashDuration))
            flashOpacity = 0
            SignalEngine.shared.ingest(.stimulusEvent(color: "dark", isOnset: true,
                                                      timestamp: ProcessInfo.processInfo.systemUptime))
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        capture.stop()
        finished = true
        LiveMeasurements.shared.record(test: test, series: SignalEngine.shared.series)
    }
}

/// Real biomarker values from the live tests in the current check, by catalog code.
@MainActor
final class LiveMeasurements {
    static let shared = LiveMeasurements()
    private(set) var values: [String: Double] = [:]

    func clear() { values.removeAll() }

    /// One summary per biomarker for the run. Saccade velocity is the run's peak; pursuit gain, blink rate
    /// and pupil asymmetry are the median of what the computer published; PLR amplitude is the median of
    /// the flash responses. A biomarker with no valid reading is left out, never guessed.
    func record(test: GraphTest, series: [String: [Double]]) {
        func median(_ xs: [Double]?) -> Double? {
            guard let xs, !xs.isEmpty else { return nil }
            let s = xs.sorted()
            return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        }
        switch test {
        case .followTheDot:
            if let v = series["saccade_peak_velocity_v1"]?.max() { values["BMK-00080"] = v }
            if let v = median(series["smooth_pursuit_gain_v1"]) { values["BMK-00084"] = v }
        case .holdAndLook:
            if let v = series["blink_rate_v1"]?.last { values["BMK-00006"] = v }
        case .lightResponse:
            if let v = median(series["pupil_asymmetry_v1"]) { values["BMK-00075"] = v }
            if let v = median(series["plr_amplitude_v1"]) { values["BMK-00069"] = v }
        default:
            break
        }
    }
}

// MARK: - Live test screen

/// The camera feed with the test's stimulus on top: a moving dot, a fixation dot, or full-screen flashes.
struct LiveTestScreen: View {
    let test: GraphTest
    let index: Int
    let count: Int
    let onDone: () -> Void
    let onEnd: () -> Void

    @StateObject private var runner: LiveTestRunner

    init(test: GraphTest, index: Int, count: Int, onDone: @escaping () -> Void, onEnd: @escaping () -> Void) {
        self.test = test
        self.index = index
        self.count = count
        self.onDone = onDone
        self.onEnd = onEnd
        _runner = StateObject(wrappedValue: LiveTestRunner(test: test))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ARFacePreview(session: runner.capture.previewSession, flashOpacity: runner.flashOpacity)
                    .ignoresSafeArea()
                stimulus(geo.size)
                chrome
            }
            .onAppear { runner.begin(stageWidthPt: geo.size.width) }
            .onDisappear { runner.cancel() }
        }
        .onChange(of: runner.finished) { _, done in if done { onDone() } }
    }

    @ViewBuilder
    private func stimulus(_ size: CGSize) -> some View {
        switch test {
        case .followTheDot:
            Circle().fill(Color.yellow)
                .frame(width: 28, height: 28)
                .position(x: size.width * runner.dot.x, y: size.height * runner.dot.y)
        case .holdAndLook:
            Circle().fill(Color.yellow).frame(width: 18, height: 18)
        default:
            EmptyView()
        }
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow("\(index + 1) of \(count)", color: test.tint)
                Spacer()
                tracking
                Button(action: { runner.cancel(); onEnd() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel("End check")
            }
            Text(test.name).font(Typeface.display(26)).foregroundStyle(.white)
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(test.tint).frame(width: bar.size.width * min(runner.elapsed / runner.duration, 1))
                }
            }
            .frame(height: 5)
            Spacer()
            Text(test.instruction)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(Space.gutter)
        .opacity(runner.flashOpacity > 0 ? 0 : 1)
    }

    private var tracking: some View {
        let found = runner.capture.state.isTracked
        return HStack(spacing: 6) {
            Circle().fill(found ? Palette.steady : Palette.flag).frame(width: 8, height: 8)
            Text(found ? "Eyes tracked" : "Eyes not found")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }
}
