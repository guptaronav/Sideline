// BlinkRateV1.swift
// Feature: blink_rate_v1 (eyelid)
//
// Counts blink events in a rolling 30-second window and publishes
// blinks-per-minute. A blink event is detected when the average of
// eyeBlinkLeft and eyeBlinkRight crosses 0.5 in the rising direction.

import ARKit
import Foundation

@MainActor
final class BlinkRateV1: SignalComputer {
    static let signalId: String = "blink_rate_v1"
    static let sampleKinds: Set<SignalSampleKind> = [.faceAnchor]

    private static let openThreshold:  Float = 0.20
    private static let closedThreshold: Float = 0.50
    private static let windowSeconds: TimeInterval = 30

    /// State machine: are we currently in a "closed" state?
    private var inClosed: Bool = false
    /// Timestamps of detected rising-edge blink events.
    private var events: [TimeInterval] = []

    func reset() {
        inClosed = false
        events.removeAll(keepingCapacity: true)
    }

    func consume(_ sample: SignalSample, engine: SignalEngine) {
        guard case let .faceAnchor(anchor, ts) = sample else { return }
        let l = anchor.blendShapes[.eyeBlinkLeft]?.floatValue  ?? 0
        let r = anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        let mean = (l + r) / 2

        // Schmitt-trigger state machine to debounce rapid oscillation.
        if !inClosed, mean >= Self.closedThreshold {
            inClosed = true
            events.append(ts)
        } else if inClosed, mean <= Self.openThreshold {
            inClosed = false
        }

        // Drop events older than the window.
        let cutoff = ts - Self.windowSeconds
        while let first = events.first, first < cutoff { events.removeFirst() }

        // blinks-per-minute = events-in-window * (60 / window-length).
        // Use elapsed-since-first-event if shorter than full window so we
        // don't under-report at the start of a capture.
        let elapsed = events.isEmpty
            ? Self.windowSeconds
            : max(1.0, min(Self.windowSeconds, ts - (events.first ?? ts)))
        let perMin = Double(events.count) / elapsed * 60.0
        engine.publish(Self.signalId, value: perMin, timestamp: ts)
    }
}
