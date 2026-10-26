import Foundation
import Observation

// All data in this file is fictional and simulated. No real athlete, no real measurement.

enum RecoveryStatus: Equatable {
    case baselineSet
    case flagged
    case evaluationRequested
    case recovering(step: Int)
    /// The athlete has finished `step`; a provider decides what happens next.
    case awaitingProvider(step: Int)
    case providerSignedOff(by: String)
}

enum Role: String, CaseIterable, Identifiable {
    case athlete, coach, provider
    var id: String { rawValue }

    var title: String {
        switch self {
        case .athlete:  "Athlete"
        case .coach:    "Coach"
        case .provider: "Provider"
        }
    }

    var blurb: String {
        switch self {
        case .athlete:  "Follow your own recovery. See your steps, log symptoms, know what comes next."
        case .coach:    "Manage your roster. Run sideline checks and send reports to a provider."
        case .provider: "Review reports, record your evaluation, and decide each step."
        }
    }
}

enum Actor {
    case athlete, coach, provider, system

    var label: String {
        switch self {
        case .athlete:  "Athlete"
        case .coach:    "Coach"
        case .provider: "Provider"
        case .system:   "Sideline"
        }
    }
}

struct LogEvent: Identifiable, Equatable {
    let id = UUID()
    let when: String
    let actor: Actor
    let text: String
}

enum RosterGroup: Int, CaseIterable {
    case attention, recovering, signedOff, ready

    var title: String {
        switch self {
        case .attention:  "Needs attention"
        case .recovering: "In recovery"
        case .signedOff:  "Provider sign-off on file"
        case .ready:      "Baseline on file"
        }
    }
}

/// Graduated return-to-sport steps, after the 2022 Amsterdam consensus statement.
enum ReturnStep: Int, CaseIterable, Identifiable {
    case symptomLimited = 1, aerobic, sportSpecific, nonContact, fullContact, returnToSport

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .symptomLimited: "Symptom-limited activity"
        case .aerobic:        "Aerobic exercise"
        case .sportSpecific:  "Individual sport-specific exercise"
        case .nonContact:     "Non-contact training"
        case .fullContact:    "Full-contact practice"
        case .returnToSport:  "Return to sport"
        }
    }
}

enum StepState { case done, current, upcoming }

struct DayReading: Identifiable, Equatable {
    let day: Int
    /// Distance from the athlete's own baseline. 1.0 is the edge of their normal range.
    let distance: Double
    var id: Int { day }
}

struct Metric: Identifiable, Equatable {
    let name: String
    let unit: String
    let baseline: Double
    let today: Double
    let tolerance: Double
    let decimals: Int

    var id: String { name }
    var deviation: Double { (today - baseline) / tolerance }
    var isOutsideRange: Bool { abs(deviation) > 1 }

    func formatted(_ value: Double) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

struct Athlete: Identifiable, Equatable {
    let number: Int
    let name: String
    let sport: String
    var status: RecoveryStatus
    var detail: String
    var history: [DayReading] = []
    var injuryMetrics: [Metric] = []
    var events: [LogEvent] = []

    var id: Int { number }

    var currentStep: Int? {
        switch status {
        case .recovering(let step), .awaitingProvider(let step): step
        default: nil
        }
    }

    /// Largest deviation from baseline on the injury-day check, used as day 1 of recovery.
    var injuryDistance: Double {
        injuryMetrics.map { abs($0.deviation) }.max() ?? 0
    }

    func updating(status: RecoveryStatus, detail: String, event: LogEvent? = nil) -> Athlete {
        var copy = self
        copy.status = status
        copy.detail = detail
        if let event { copy.events.append(event) }
        return copy
    }

    var group: RosterGroup {
        switch status {
        case .flagged, .evaluationRequested, .awaitingProvider: .attention
        case .recovering:                 .recovering
        case .providerSignedOff:          .signedOff
        case .baselineSet:                .ready
        }
    }

    var showsSteps: Bool {
        switch status {
        case .recovering, .awaitingProvider, .providerSignedOff: true
        default: false
        }
    }

    /// Three consecutive days inside the athlete's own range.
    var isReadyForProviderReview: Bool {
        guard case .recovering = status, history.count >= 3 else { return false }
        return history.suffix(3).allSatisfy { $0.distance <= 1.0 }
    }

    func state(of step: ReturnStep) -> StepState {
        switch status {
        case .recovering(let current):
            if step.rawValue < current { return .done }
            return step.rawValue == current ? .current : .upcoming
        case .awaitingProvider(let completed):
            return step.rawValue <= completed ? .done : .upcoming
        case .providerSignedOff:
            return .done
        default:
            return .upcoming
        }
    }
}

extension Metric {
    /// What the simulated sideline check "measures" for the demo athlete.
    static let demoInjuryDay: [Metric] = [
        Metric(name: "Smooth-pursuit gain", unit: "", baseline: 0.92, today: 0.74, tolerance: 0.08, decimals: 2),
        Metric(name: "Saccade peak velocity", unit: "°/s", baseline: 480, today: 395, tolerance: 55, decimals: 0),
        Metric(name: "Pupil constriction", unit: "%", baseline: 31, today: 22, tolerance: 4, decimals: 0),
        Metric(name: "Light-reflex latency", unit: "ms", baseline: 240, today: 268, tolerance: 30, decimals: 0),
    ]
}

private func series(_ values: [Double]) -> [DayReading] {
    values.enumerated().map { DayReading(day: $0.offset + 1, distance: $0.element) }
}

private func event(_ when: String, _ actor: Actor, _ text: String) -> LogEvent {
    LogEvent(when: when, actor: actor, text: text)
}

extension Athlete {
    static let sample: [Athlete] = [
        Athlete(number: 14, name: "Devon K.", sport: "Football · Linebacker",
                status: .flagged, detail: "Removed from play 9:42 PM",
                injuryMetrics: Metric.demoInjuryDay,
                events: [event("9:42 PM", .coach, "Removed from play after sideline check. 3 of 4 measures outside baseline range.")]),
        Athlete(number: 3, name: "Elena V.", sport: "Soccer · Defender",
                status: .recovering(step: 3), detail: "Day 7 · step 3 of 6",
                history: series([2.9, 2.3, 1.8, 1.4, 1.0, 0.8, 0.7]),
                events: [
                    event("Day 1", .coach, "Removed from play after sideline check."),
                    event("Day 2", .provider, "Evaluation recorded by M. Okafor, MD. Begin step 1."),
                    event("Day 4", .provider, "Approved step 2."),
                    event("Day 6", .provider, "Approved step 3."),
                    event("Day 7", .athlete, "Symptom check-in: no symptoms."),
                ]),
        Athlete(number: 9, name: "Priya S.", sport: "Volleyball · Setter",
                status: .recovering(step: 2), detail: "Day 5 · step 2 of 6",
                history: series([2.6, 2.2, 1.9, 1.5, 1.2]),
                events: [
                    event("Day 1", .coach, "Removed from play after sideline check."),
                    event("Day 2", .provider, "Evaluation recorded by M. Okafor, MD. Begin step 1."),
                    event("Day 4", .provider, "Approved step 2."),
                    event("Day 5", .athlete, "Symptom check-in: total 2 of 15 (worst: Headache 1)."),
                ]),
        Athlete(number: 21, name: "Tyler B.", sport: "Football · Running back",
                status: .providerSignedOff(by: "R. Alvarez, ATC"), detail: "Sign-off recorded day 12",
                history: series([2.7, 2.4, 2.0, 1.7, 1.4, 1.1, 0.9, 0.8, 0.8, 0.7, 0.6, 0.6]),
                events: [
                    event("Day 1", .coach, "Removed from play after sideline check."),
                    event("Day 2", .provider, "Evaluation recorded by R. Alvarez, ATC. Begin step 1."),
                    event("Day 12", .provider, "Return-to-play sign-off recorded by R. Alvarez, ATC."),
                ]),
        Athlete(number: 7, name: "Marcus T.", sport: "Football · Quarterback",
                status: .baselineSet, detail: "Recorded Aug 14",
                events: [event("Aug 14", .coach, "Baseline recorded.")]),
        Athlete(number: 11, name: "Sam O.", sport: "Soccer · Forward",
                status: .baselineSet, detail: "Recorded Aug 14",
                events: [event("Aug 14", .coach, "Baseline recorded.")]),
    ]
}

/// Which dashboard is showing, and who the demo is signed in as.
@Observable
final class Session {
    var role: Role?
    var athleteID = 3
    let providerName = "M. Okafor, MD"
}

@Observable
final class Store {
    private(set) var athletes: [Athlete] = Athlete.sample

    func athlete(_ id: Int) -> Athlete? {
        athletes.first { $0.id == id }
    }

    // Coach

    func flag(_ id: Int) {
        update(id) {
            var copy = $0.updating(
                status: .flagged,
                detail: "Removed from play just now",
                event: event("Just now", .coach, "Removed from play after sideline check. 3 of 4 measures outside baseline range.")
            )
            copy.injuryMetrics = Metric.demoInjuryDay
            return copy
        }
    }

    func requestEvaluation(_ id: Int) {
        update(id) {
            $0.updating(status: .evaluationRequested, detail: "Report with provider",
                        event: event("Just now", .coach, "Report sent to provider for evaluation."))
        }
    }

    func sendToProvider(_ id: Int) {
        update(id) {
            $0.updating(status: .awaitingProvider(step: $0.currentStep ?? 1), detail: "Return review requested",
                        event: event("Just now", .coach, "Three days inside baseline range. Sent to provider for review."))
        }
    }

    // Athlete

    func logSymptoms(_ id: Int, summary: String) {
        update(id) {
            var copy = $0
            copy.events.append(event("Just now", .athlete, summary))
            return copy
        }
    }

    // Provider

    func beginRecovery(_ id: Int, by provider: String) {
        update(id) {
            var copy = $0.updating(
                status: .recovering(step: 1), detail: "Day 1 · step 1 of 6",
                event: event("Just now", .provider, "Evaluation recorded by \(provider). Begin step 1.")
            )
            copy.history = [DayReading(day: 1, distance: $0.injuryDistance)]
            return copy
        }
    }

    func approveNextStep(_ id: Int, by provider: String) {
        update(id) {
            let next = min(($0.currentStep ?? 1) + 1, 6)
            return $0.updating(status: .recovering(step: next), detail: "Step \(next) of 6",
                               event: event("Just now", .provider, "Approved step \(next)."))
        }
    }

    func hold(_ id: Int) {
        update(id) {
            let step = $0.currentStep ?? 1
            return $0.updating(status: .recovering(step: step), detail: "Held at step \(step)",
                               event: event("Just now", .provider, "Held at step \(step). Continue and re-review."))
        }
    }

    func signOff(_ id: Int, by provider: String) {
        update(id) {
            $0.updating(status: .providerSignedOff(by: provider), detail: "Sign-off recorded just now",
                        event: event("Just now", .provider, "Return-to-play sign-off recorded by \(provider)."))
        }
    }

    func addProviderNote(_ id: Int, _ text: String) {
        update(id) {
            var copy = $0
            copy.events.append(event("Just now", .provider, text))
            return copy
        }
    }

    private func update(_ id: Int, _ change: (Athlete) -> Athlete) {
        athletes = athletes.map { $0.id == id ? change($0) : $0 }
    }
}
