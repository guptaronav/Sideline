import Foundation

// Snapshot of the OculoDx knowledge graph (apps/admin-portal/data/research, commit 785e3dff).
// The app reads tests, durations, biomarkers and the model from here, never from its own copy of the science.
// Later this comes from the catalog MCP endpoint and is cached on device.

enum GraphTest: String, CaseIterable, Identifiable {
    case lightResponse = "light-response"
    case followTheDot = "follow-the-dot"
    case holdAndLook = "hold-and-look"
    case dynamicVisualAcuity = "head-turn"
    case closeUpEyePhoto = "close-up-eye-photo"

    var id: String { rawValue }

    var code: String {
        switch self {
        case .lightResponse:       "TST-00006"
        case .followTheDot:        "TST-00002"
        case .holdAndLook:         "TST-00005"
        case .dynamicVisualAcuity: "TST-00004"
        case .closeUpEyePhoto:     "TST-00001"
        }
    }

    /// Catalog display_name.
    var name: String {
        switch self {
        case .lightResponse:       "Light Response"
        case .followTheDot:        "Follow the Dot"
        case .holdAndLook:         "Hold & Look"
        case .dynamicVisualAcuity: "Dynamic Visual Acuity / Gaze Stabilization"
        case .closeUpEyePhoto:     "Close-up Eye Photo"
        }
    }

    /// Catalog duration_seconds.
    var seconds: Int {
        switch self {
        case .lightResponse:       15
        case .followTheDot:        75
        case .holdAndLook:         30
        case .dynamicVisualAcuity: 60
        case .closeUpEyePhoto:     60
        }
    }

    /// Catalog constraint: who holds the phone and which camera.
    var constraint: String {
        self == .closeUpEyePhoto ? "two-person-rear" : "solo-front"
    }

    /// What the athlete hears and reads. Plain words, no science.
    var instruction: String {
        switch self {
        case .lightResponse:       "Keep your eyes open. The screen goes dark, then flashes three times."
        case .followTheDot:        "Follow the dot with your eyes. Keep your head still."
        case .holdAndLook:         "Hold the phone steady and look at the screen."
        case .dynamicVisualAcuity: "Turn your head side to side and tap where the E points."
        case .closeUpEyePhoto:     "Coach: turn the phone around. Rear camera, torch on, three photos of each eye."
        }
    }

    /// One line on what it measures, in plain words.
    var measures: String {
        switch self {
        case .lightResponse:       "How the pupils react to light"
        case .followTheDot:        "Eye tracking and quick eye jumps"
        case .holdAndLook:         "Blinking and how steady the gaze is"
        case .dynamicVisualAcuity: "Seeing clearly while the head moves"
        case .closeUpEyePhoto:     "The front of each eye, for eye injuries"
        }
    }

    /// Biomarkers this test produces, by catalog code.
    var biomarkers: [String] {
        switch self {
        case .lightResponse:       ["BMK-00075", "BMK-00069", "BMK-00071", "BMK-00017"]
        case .followTheDot:        ["BMK-00080", "BMK-00084"]
        case .holdAndLook:         ["BMK-00006", "BMK-00024"]
        case .dynamicVisualAcuity: ["BMK-00159"]
        case .closeUpEyePhoto:     ["OBS-00006"]
        }
    }

    /// FTR-00162 (gaze stabilization) is planned in the catalog, so this test cannot score yet.
    var isScored: Bool { self != .dynamicVisualAcuity }
}

enum CheckKind {
    case sideline, baseline, daily

    /// Tests come from the graph: the biomarkers CND-00066 / CND-00220 need, one primary test each.
    var tests: [GraphTest] {
        switch self {
        case .sideline: [.lightResponse, .followTheDot, .holdAndLook, .closeUpEyePhoto]
        // DVA (TST-00004) stays in the baseline as practice: FTR-00162 is planned, so it can't score or move a step.
        case .baseline: [.lightResponse, .followTheDot, .holdAndLook, .dynamicVisualAcuity]
        case .daily:    [.lightResponse, .followTheDot, .holdAndLook]
        }
    }

    /// Whole minutes from the catalog's test durations.
    var minutes: Int { Int((Double(tests.reduce(0) { $0 + $1.seconds }) / 60).rounded()) }
}

/// concussion-oculomotor-screen-v1, exactly as the catalog defines it.
/// Domain flags: saccade < 350 deg/s, pursuit < 0.80, gaze stabilization < 95 deg/s, blink < 10 or > 25 /min.
/// 3+ flags -> 0.75, 1-2 -> 0.40, none -> 0.05. Status planned, unvalidated, expected AUC 0.73.
struct ConcussionModel {
    struct Input: Equatable {
        var saccadeVelocity: Double     // BMK-00080, deg/s
        var pursuitGain: Double         // BMK-00084
        var gazeStabilization: Double?  // BMK-00159, not built
        var blinkRate: Double           // BMK-00006, per minute
        var pupilAsymmetry: Double      // BMK-00075, mm
    }

    struct Flag: Identifiable {
        let test: GraphTest
        let text: String
        var id: String { text }
    }

    static func flags(_ v: Input) -> [Flag] {
        var out: [Flag] = []
        if v.saccadeVelocity < 350 {
            out.append(Flag(test: .followTheDot, text: "Quick eye jumps were slower than normal."))
        }
        if v.pursuitGain < 0.80 {
            out.append(Flag(test: .followTheDot, text: "The eyes fell behind the moving dot."))
        }
        if let g = v.gazeStabilization, g < 95 {
            out.append(Flag(test: .dynamicVisualAcuity, text: "Vision blurred when the head moved."))
        }
        if v.blinkRate < 10 || v.blinkRate > 25 {
            out.append(Flag(test: .holdAndLook, text: "Blinking was outside the normal range."))
        }
        return out
    }

    static func probability(_ v: Input) -> Double {
        switch flags(v).count {
        case 3...: 0.75
        case 1...: 0.40
        default:   0.05
        }
    }

    /// CND-00260 red flag: anisocoria over 1 mm after a head injury.
    static func isEmergency(_ v: Input) -> Bool { v.pupilAsymmetry > 1.0 }

    static let concussed = Input(saccadeVelocity: 318, pursuitGain: 0.71, gazeStabilization: nil, blinkRate: 28, pupilAsymmetry: 0.3)
}

/// Biomarkers shown to people, with the catalog's reference ranges and the model's thresholds.
/// Values are demo data: each day's value follows the athlete's recovery reading.
struct BiomarkerSpec: Identifiable {
    let code: String
    let name: String
    let plain: String
    let unit: String
    let decimals: Int
    let test: GraphTest
    let refLow: Double?
    let refHigh: Double?
    let flagBelow: Double?
    let flagAbove: Double?
    let thresholdText: String
    let baseline: Double
    let injured: Double
    let axis: ClosedRange<Double>

    var id: String { code }

    /// Demo value for a recovery reading (2.6 = injury day, 0.8 = back to normal).
    func value(distance: Double) -> Double {
        let t = min(max((distance - 0.8) / 1.8, 0), 1)
        return baseline + (injured - baseline) * t
    }

    /// Value for one day, using that day's per-biomarker reading when it has one.
    func value(_ r: DayReading) -> Double { r.measured[code] ?? value(distance: r.lagging[code] ?? r.distance) }

    /// Back at the athlete's own normal: within 15% of the gap between their baseline and their injury-day value.
    /// A value that displays the same as the baseline also counts, so the label never contradicts the number shown.
    func isAtNormal(_ v: Double) -> Bool {
        abs(v - baseline) <= 0.15 * abs(injured - baseline) || format(v) == format(baseline)
    }

    func isFlagged(_ v: Double) -> Bool {
        if let lo = flagBelow, v < lo { return true }
        if let hi = flagAbove, v > hi { return true }
        if flagBelow == nil, flagAbove == nil {
            if let lo = refLow, v < lo { return true }
            if let hi = refHigh, v > hi { return true }
        }
        return false
    }

    func format(_ v: Double) -> String {
        String(format: "%.\(decimals)f", v) + (unit.isEmpty ? "" : " \(unit)")
    }

    /// The same biomarker with a personal baseline: everyone's normal differs, and an injury shifts it by the same amount.
    func personal(_ delta: Double) -> BiomarkerSpec {
        let lo = axis.lowerBound + (axis.upperBound - axis.lowerBound) * 0.08
        let b = max(baseline + delta, lo)
        return BiomarkerSpec(code: code, name: name, plain: plain, unit: unit, decimals: decimals, test: test,
                             refLow: refLow, refHigh: refHigh, flagBelow: flagBelow, flagAbove: flagAbove,
                             thresholdText: thresholdText, baseline: b, injured: injured + (b - baseline), axis: axis)
    }

    /// How far one athlete's normal sits from the catalog default, per biomarker (demo spread, inside the reference range).
    static let spread: [String: Double] = ["BMK-00080": 45, "BMK-00084": 0.03, "BMK-00006": 3, "BMK-00069": 0.45, "BMK-00075": 0.1]

    static let tracked: [BiomarkerSpec] = [
        BiomarkerSpec(code: "BMK-00080", name: "Saccade peak velocity", plain: "How fast your eyes jump", unit: "°/s", decimals: 0,
                      test: .followTheDot, refLow: 350, refHigh: 600, flagBelow: 350, flagAbove: nil,
                      thresholdText: "Flag below 350 °/s", baseline: 452, injured: 318, axis: 280...500),
        BiomarkerSpec(code: "BMK-00084", name: "Smooth pursuit gain", plain: "How well your eyes keep up with the dot", unit: "", decimals: 2,
                      test: .followTheDot, refLow: 0.90, refHigh: 1.00, flagBelow: 0.80, flagAbove: nil,
                      thresholdText: "Flag below 0.80", baseline: 0.94, injured: 0.71, axis: 0.6...1.0),
        BiomarkerSpec(code: "BMK-00006", name: "Blink rate", plain: "Blinks per minute", unit: "/min", decimals: 0,
                      test: .holdAndLook, refLow: 12, refHigh: 20, flagBelow: 10, flagAbove: 25,
                      thresholdText: "Flag below 10 or above 25", baseline: 15, injured: 28, axis: 5...32),
        BiomarkerSpec(code: "BMK-00069", name: "PLR amplitude", plain: "How much your pupils shrink in light", unit: "mm", decimals: 1,
                      test: .lightResponse, refLow: 1.5, refHigh: 3.5, flagBelow: nil, flagAbove: nil,
                      thresholdText: "Normal 1.5 – 3.5 mm", baseline: 2.6, injured: 1.9, axis: 1.0...3.8),
        BiomarkerSpec(code: "BMK-00075", name: "Pupil asymmetry", plain: "Difference between your two pupils", unit: "mm", decimals: 1,
                      test: .lightResponse, refLow: 0, refHigh: 0.4, flagBelow: nil, flagAbove: nil,
                      thresholdText: "Normal below 0.4 mm · urgent above 1.0 mm", baseline: 0.2, injured: 0.3, axis: 0...1.2),
    ]
}
