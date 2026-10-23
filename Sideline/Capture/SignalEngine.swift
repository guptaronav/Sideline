// SignalEngine.swift
// Ported from OculoSense (apps/sensors-testing/OculoSense/Common/Signals/SignalEngine.swift).
// Kept: sample types, the SignalComputer protocol, the engine's ingest/publish core and
// OcularCalibration. Dropped: persistence, proxy isolation, smoothing and the ~90-computer
// registry. Sideline registers only the computers behind its five biomarkers.
//
// Change from the original: eye anchors are projected with the camera's native
// .landscapeRight orientation, matching the captured image buffer the pupil computers read.

import ARKit
import Combine
import Foundation
import simd

// MARK: - Sample kinds

enum SignalSampleKind: Hashable {
    case faceAnchor
    case imu
    case audioBuffer
    case stimulusEvent
    case stimulusPositionEvent      // direction-keyed stimulus (anti-saccade, OKN, …)
    case userInput
    case cameraFrame
}

/// Direction of a positional stimulus. Used by anti-saccade, smooth-pursuit
/// step, OKN, and the 9-position gaze protocol. The 9-position protocol
/// uses the four diagonal cases (upLeft, upRight, downLeft, downRight) in
/// addition to the cardinals.
enum StimulusPosition: String {
    case center, left, right, up, down
    case upLeft, upRight, downLeft, downRight

    /// Whether this is a non-primary gaze position (anything but .center).
    /// Used by computers that only score during peripheral fixations.
    var isEccentric: Bool { self != .center }

    /// Horizontal axis component: -1 (left), 0 (center), +1 (right).
    var horizontalSign: Int {
        switch self {
        case .left, .upLeft, .downLeft:   return -1
        case .right, .upRight, .downRight: return  1
        default:                          return  0
        }
    }

    /// Vertical axis component: -1 (down), 0 (center), +1 (up).
    var verticalSign: Int {
        switch self {
        case .up, .upLeft, .upRight:     return  1
        case .down, .downLeft, .downRight: return -1
        default:                         return  0
        }
    }
}

/// Per-eye geometric anchor pre-digested by the sensor (S03 / S01) so the
/// signal computers don't have to import ARKit or recompute projection.
struct EyeImageAnchor {
    /// Pupil center projected into the captured-image pixel space.
    let imagePoint: CGPoint
    /// Distance from the front camera to the pupil center, in meters.
    let depthMeters: Float
}

enum SignalSample {
    case faceAnchor(ARFaceAnchor, timestamp: TimeInterval)
    /// RGB camera frame with sensor-pre-digested geometric anchors at each
    /// eye. Pupil-family signals subscribe to this.
    case cameraFrame(rgbBuffer: CVPixelBuffer,
                     left: EyeImageAnchor?,
                     right: EyeImageAnchor?,
                     focalLengthPx: Float,
                     imageWidth: Int,
                     imageHeight: Int,
                     timestamp: TimeInterval)
    /// Stimulus-onset / offset event from S06 (or S07-embedded stimulus).
    /// PLR + saccade-latency + qCSF / scotopic / color-discrim signals
    /// subscribe to align their measurement windows to these events.
    case stimulusEvent(color: String, isOnset: Bool, timestamp: TimeInterval)
    /// Positional stimulus — direction-keyed rather than color-keyed. Used
    /// by the anti-saccade protocol (S10) to tell its computer where the
    /// peripheral target appeared so error-vs-correct can be scored from
    /// the first saccade after onset.
    case stimulusPositionEvent(position: StimulusPosition,
                               isOnset: Bool,
                               timestamp: TimeInterval)
}

extension SignalSample {
    var kind: SignalSampleKind {
        switch self {
        case .faceAnchor:            return .faceAnchor
        case .cameraFrame:           return .cameraFrame
        case .stimulusEvent:         return .stimulusEvent
        case .stimulusPositionEvent: return .stimulusPositionEvent
        }
    }
}

// MARK: - Computer protocol

protocol SignalComputer: AnyObject {
    /// Must match the `id` field in signals.json.
    static var signalId: String { get }
    /// Which sample kinds this computer wants to receive.
    static var sampleKinds: Set<SignalSampleKind> { get }

    func consume(_ sample: SignalSample, engine: SignalEngine)
    func reset()
}

extension SignalComputer {
    func reset() {}
}

// MARK: - Engine

@MainActor
final class SignalEngine: ObservableObject {
    static let shared = SignalEngine()

    /// Latest value per signal_id.
    @Published private(set) var values: [String: Double] = [:]
    /// Every value published since the last reset, per signal_id. A run's summary reads these.
    private(set) var series: [String: [Double]] = [:]

    private var computers: [String: any SignalComputer] = [:]
    private var byKind: [SignalSampleKind: [String]] = [:]
    private var registered = false

    private init() {}

    func register(_ computer: any SignalComputer) {
        let id = type(of: computer).signalId
        computers[id] = computer
        for k in type(of: computer).sampleKinds {
            byKind[k, default: []].append(id)
        }
    }

    /// Fans a sample out to interested computers, in registration order.
    func ingest(_ sample: SignalSample) {
        guard let ids = byKind[sample.kind] else { return }
        for id in ids {
            computers[id]?.consume(sample, engine: self)
        }
    }

    /// Called by computers.
    func publish(_ signalId: String, value: Double, timestamp: TimeInterval) {
        values[signalId] = value
        series[signalId, default: []].append(value)
    }

    func resetAll() {
        for c in computers.values { c.reset() }
        values.removeAll()
        series.removeAll()
    }

    /// The computers behind Sideline's biomarkers. Pupil baseline must come before the PLR
    /// computers: PLR reads its latest value on each camera frame.
    func registerSidelineComputers() {
        guard !registered else { return }
        registered = true
        register(SaccadePeakVelocityV1())
        register(SmoothPursuitGainV1())
        register(BlinkRateV1())
        register(GazeDeviationHorizontalV1())
        register(VergenceAngleV1())
        register(PupilDiameterBaselineV1())
        register(PupilAsymmetryV1())
        register(PLRAmplitudeV1())
        register(PLRLatencyV1())
        register(ConstrictionVelocityV1())
    }
}

// MARK: - Ocular calibration

enum OcularCalibration {
    /// Approximate iPhone "logical points per millimetre" of physical
    /// screen. Constant across modern iPhones within ±5 %.
    static let pointsPerMm: Double = 6.0

    /// Camera-to-face Euclidean distance in metres for the given face
    /// anchor + frame. Falls back to a default if either transform is
    /// missing data (shouldn't happen but protects against NaN).
    static func faceDistanceM(camera: matrix_float4x4,
                              face: matrix_float4x4,
                              fallback: Float = 0.30) -> Float {
        let cp = simd_float3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        let fp = simd_float3(face.columns.3.x, face.columns.3.y, face.columns.3.z)
        let d = simd_length(cp - fp)
        return d.isFinite && d > 0 ? d : fallback
    }

    /// On-screen offset (points) from center that subtends the given
    /// visual angle at the given viewing distance.
    ///   offsetMm = distanceMm × tan(angle)
    ///   offsetPt = offsetMm × pointsPerMm
    static func pointOffset(forAngleDeg angle: Double,
                            faceDistanceM dist: Float) -> CGFloat {
        let distMm = max(0.15, Double(dist)) * 1000.0   // floor 15 cm
        let offsetMm = distMm * tan(angle * .pi / 180.0)
        return CGFloat(offsetMm * pointsPerMm)
    }

    /// Inverse: what visual angle does a given on-screen offset subtend
    /// at the given viewing distance? Used to honestly report the angle
    /// the participant is *actually* seeing when we've capped or
    /// fudged the offset.
    static func visualAngleDeg(forOffsetPt offsetPt: CGFloat,
                               faceDistanceM dist: Float) -> Double {
        let distMm = max(0.15, Double(dist)) * 1000.0
        let offsetMm = Double(offsetPt) / pointsPerMm
        return atan(offsetMm / distMm) * 180.0 / .pi
    }

    /// Pupil position in world coordinates given a face anchor + one of
    /// its leftEyeTransform / rightEyeTransform. ARKit places the eye
    /// transform's origin at the eye's *rotation centre*; the pupil is
    /// ~10 mm in front of that along the eye's forward axis (-Z).
    ///
    /// Used by ARKit-driven capture views (S03, S11) when constructing
    /// EyeImageAnchor pairs to project into the camera image.
    static func pupilWorldPosition(faceAnchor: ARFaceAnchor,
                                   eyeTransform: simd_float4x4) -> simd_float3 {
        let eyeWorld = faceAnchor.transform * eyeTransform
        let center = simd_float3(eyeWorld.columns.3.x,
                                 eyeWorld.columns.3.y,
                                 eyeWorld.columns.3.z)
        let forward = -simd_normalize(simd_float3(eyeWorld.columns.2.x,
                                                  eyeWorld.columns.2.y,
                                                  eyeWorld.columns.2.z))
        return center + 0.010 * forward
    }

    /// Convenience: build a pair of EyeImageAnchors directly from an
    /// ARFrame + face anchor. Centralises the S03 boilerplate so other
    /// ARKit-driven capture screens (S11, future) get pixel-accurate
    /// anchors without re-implementing the projection chain.
    static func eyeAnchors(from face: ARFaceAnchor,
                           camera: ARCamera) -> (left: EyeImageAnchor,
                                                 right: EyeImageAnchor) {
        let imageRes = camera.imageResolution
        let cameraTranslation = simd_float3(
            camera.transform.columns.3.x,
            camera.transform.columns.3.y,
            camera.transform.columns.3.z
        )
        let lWorld = pupilWorldPosition(faceAnchor: face,
                                        eyeTransform: face.leftEyeTransform)
        let rWorld = pupilWorldPosition(faceAnchor: face,
                                        eyeTransform: face.rightEyeTransform)
        let lPt = camera.projectPoint(lWorld, orientation: .landscapeRight,
                                      viewportSize: imageRes)
        let rPt = camera.projectPoint(rWorld, orientation: .landscapeRight,
                                      viewportSize: imageRes)
        return (
            EyeImageAnchor(imagePoint: lPt,
                           depthMeters: simd_length(lWorld - cameraTranslation)),
            EyeImageAnchor(imagePoint: rPt,
                           depthMeters: simd_length(rWorld - cameraTranslation))
        )
    }
}

