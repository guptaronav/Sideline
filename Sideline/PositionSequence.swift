import Foundation

/// Shared dimensions for the real camera and simulator preview.
/// A human-head guide is only slightly taller than it is wide; it is not a portrait-photo frame.
struct PositionComposition {
    static let faceGuideHeightToWidth = 1.16
    static let fallbackMeshRows = 22
    static let fallbackMeshColumns = 18
}

struct PositionSequenceState: Equatable {
    let completedChecks: Int
    let meshOpacity: Double
    let isReady: Bool
    let countdown: Int
}

/// Timing for the simulated camera-readiness phase.
/// The AR mesh stays visible while the first checks pass, fades during the last check,
/// and leaves the athlete's clean photo visible for the 3-2-1 countdown.
struct PositionSequence {
    static let checks = ["Face found", "Distance about 30 cm", "Light is even", "Both eyes visible"]
    static let perCheck = 0.6
    static let countdownSeconds = 3.0
    static let length = Double(checks.count) * perCheck + countdownSeconds

    func state(at elapsed: Double) -> PositionSequenceState {
        let safeElapsed = max(elapsed, 0)
        let completed = min(Int(safeElapsed / Self.perCheck), Self.checks.count)
        let readyAt = Double(Self.checks.count) * Self.perCheck
        let fadeStartsAt = readyAt - Self.perCheck
        let meshOpacity: Double
        if safeElapsed <= fadeStartsAt {
            meshOpacity = 1
        } else if safeElapsed >= readyAt {
            meshOpacity = 0
        } else {
            meshOpacity = 1 - ((safeElapsed - fadeStartsAt) / Self.perCheck)
        }

        return PositionSequenceState(
            completedChecks: completed,
            meshOpacity: meshOpacity,
            isReady: completed == Self.checks.count,
            countdown: max(Int(ceil(Self.length - safeElapsed)), 1)
        )
    }
}
