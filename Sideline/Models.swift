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
}

enum Team: String {
    case ridgeline, chesapeake

    var name: String { self == .ridgeline ? "Ridgeline Academy" : "Chesapeake State" }
    var squad: String { self == .ridgeline ? "Youth MMA team · ages 11–14" : "Men’s basketball" }
}

/// A coach can run more than one team.
enum Squad: String, CaseIterable, Identifiable, Hashable {
    case mmaYouth, mmaTeen, mensBasketball, womensBasketball
    var id: String { rawValue }

    var team: Team { self == .mmaYouth || self == .mmaTeen ? .ridgeline : .chesapeake }

    var name: String {
        switch self {
        case .mmaYouth:         "Youth team · ages 11–14"
        case .mmaTeen:          "Teen team · ages 15–17"
        case .mensBasketball:   "Men’s basketball"
        case .womensBasketball: "Women’s basketball"
        }
    }

    var shortName: String {
        switch self {
        case .mmaYouth:         "Youth"
        case .mmaTeen:          "Teens"
        case .mensBasketball:   "Men’s"
        case .womensBasketball: "Women’s"
        }
    }
}

/// Each demo account is a different person signing in. Each sees only their own app.
enum DemoAccount: String, CaseIterable, Identifiable {
    case sid, hayes, dana, marcus, priya, jalen, okafor
    var id: String { rawValue }

    var name: String {
        switch self {
        case .sid:  "Sid Gupta"
        case .hayes:  "Andre Hayes"
        case .dana:   "Dana Whitfield"
        case .marcus: "Marcus Bell"
        case .priya:  "Priya Nair"
        case .jalen:  "Jalen Brooks"
        case .okafor: "Dr. Tom Okafor"
        }
    }

    var subtitle: String {
        switch self {
        case .sid:  "Instructor · 1st degree black belt"
        case .hayes:  "Head coach · Men’s basketball"
        case .dana:   "Coach · Ridgeline Academy youth team"
        case .marcus: "Athletic trainer · Chesapeake State basketball"
        case .priya:  "Athlete · 13 · Ridgeline Academy, yellow belt"
        case .jalen:  "Athlete · 20 · Chesapeake State, guard"
        case .okafor: "Team physician · sports medicine"
        }
    }

    var role: Role {
        switch self {
        case .sid, .hayes, .dana, .marcus:  .coach
        case .priya, .jalen:  .athlete
        case .okafor:         .provider
        }
    }

    var team: Team? {
        switch self {
        case .sid, .dana, .priya:   .ridgeline
        case .hayes, .marcus, .jalen: .chesapeake
        case .okafor:         nil
        }
    }

    var email: String {
        switch self {
        case .sid:  "sid@ridgelineacademy.com"
        case .hayes:  "andre@chessu.edu"
        case .dana:   "dana@ridgelineacademy.com"
        case .marcus: "marcus@chessu.edu"
        case .priya:  "priya@ridgelineacademy.com"
        case .jalen:  "jalen@chessu.edu"
        case .okafor: "tom@chessu.edu"
        }
    }

    var look: AvatarLook {
        switch self {
        case .dana:   AvatarLook(skin: 0xE8B48F, hair: .short, hairColor: 0x3B2618, kit: .polo(color: 0x0E6E6A), backdrop: 0xDDEFEB)
        case .marcus: AvatarLook(skin: 0x7A4A2E, hair: .buzz, hairColor: 0x141414, kit: .polo(color: 0x13294B), backdrop: 0xE3E8F2)
        case .hayes:  AvatarLook(skin: 0x5A3825, hair: .buzz, hairColor: 0x141414, kit: .polo(color: 0x13294B), backdrop: 0xE3E8F2)
        case .sid:  AvatarLook(skin: 0xC98E62, hair: .short, hairColor: 0x1E1A1A, kit: .polo(color: 0x0E6E6A), backdrop: 0xDDEFEB)
        case .priya:  Athlete.sample.first { $0.number == 51 }!.look
        case .jalen:  Athlete.sample.first { $0.number == 3 }!.look
        case .okafor: AvatarLook(skin: 0x5A3825, hair: .short, hairColor: 0x2A2A2A, kit: .polo(color: 0x2B2F36), backdrop: 0xECEDEF)
        }
    }

    var squads: [Squad] {
        switch self {
        case .sid, .dana: [.mmaYouth, .mmaTeen]
        case .hayes:        [.mensBasketball]
        case .marcus: [.mensBasketball, .womensBasketball]
        default:      []
        }
    }

    var athleteID: Int? {
        switch self {
        case .priya: 51
        case .jalen: 3
        default:     nil
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
        case .ready:      "Ready"
        }
    }
}

/// Sports a person plays. Each has its own SF Symbols athlete silhouette (all checked to exist),
/// used on sport tiles and team art.
enum Sport: String, CaseIterable, Identifiable {
    // Team
    case americanFootball = "Football", basketball = "Basketball", soccer = "Soccer", baseball = "Baseball"
    case softball = "Softball", volleyball = "Volleyball", iceHockey = "Ice hockey", fieldHockey = "Field hockey"
    case lacrosse = "Lacrosse", rugby = "Rugby", handball = "Handball", waterPolo = "Water polo"
    case cricket = "Cricket", australianFootball = "Aussie rules", ultimate = "Ultimate", cheer = "Cheer"
    // Combat
    case mma = "MMA", wrestling = "Wrestling", boxing = "Boxing", kickboxing = "Kickboxing"
    case fencing = "Fencing", taiChi = "Tai chi"
    // Racquet
    case tennis = "Tennis", badminton = "Badminton", squash = "Squash", racquetball = "Racquetball"
    case pickleball = "Pickleball", tableTennis = "Table tennis"
    // Individual
    case track = "Track and field", running = "Cross country", gymnastics = "Gymnastics", dance = "Dance"
    case weightlifting = "Weightlifting", cycling = "Cycling", climbing = "Climbing", golf = "Golf"
    case equestrian = "Equestrian", archery = "Archery", bowling = "Bowling", skateboarding = "Skateboarding"
    case hockeyRoller = "Roller hockey"
    // Water
    case swimming = "Swimming", openWater = "Open water", rowing = "Rowing", sailing = "Sailing", surfing = "Surfing"
    // Winter
    case skiing = "Skiing", crossCountrySkiing = "Nordic skiing", snowboarding = "Snowboarding"
    case figureSkating = "Figure skating", speedSkating = "Speed skating", curling = "Curling"

    var id: String { rawValue }

    enum Group: String, CaseIterable { case team = "Team", combat = "Combat", racquet = "Racquet", individual = "Individual", water = "Water", winter = "Winter" }

    var group: Group {
        switch self {
        case .americanFootball, .basketball, .soccer, .baseball, .softball, .volleyball, .iceHockey, .fieldHockey,
             .lacrosse, .rugby, .handball, .waterPolo, .cricket, .australianFootball, .ultimate, .cheer: .team
        case .mma, .wrestling, .boxing, .kickboxing, .fencing, .taiChi: .combat
        case .tennis, .badminton, .squash, .racquetball, .pickleball, .tableTennis: .racquet
        case .swimming, .openWater, .rowing, .sailing, .surfing: .water
        case .skiing, .crossCountrySkiing, .snowboarding, .figureSkating, .speedSkating, .curling: .winter
        default: .individual
        }
    }

    var symbol: String {
        switch self {
        case .americanFootball:   "figure.american.football"
        case .basketball:         "figure.basketball"
        case .soccer:             "figure.soccer"
        case .baseball:           "figure.baseball"
        case .softball:           "figure.softball"
        case .volleyball:         "figure.volleyball"
        case .iceHockey:          "figure.ice.hockey"
        case .fieldHockey:        "figure.field.hockey"
        case .lacrosse:           "figure.lacrosse"
        case .rugby:              "figure.rugby"
        case .handball:           "figure.handball"
        case .waterPolo:          "figure.waterpolo"
        case .cricket:            "figure.cricket"
        case .australianFootball: "figure.australian.football"
        case .ultimate:           "figure.disc.sports"
        case .cheer:              "figure.socialdance"
        case .mma:                "figure.martial.arts"
        case .wrestling:          "figure.wrestling"
        case .boxing:             "figure.boxing"
        case .kickboxing:         "figure.kickboxing"
        case .fencing:            "figure.fencing"
        case .taiChi:             "figure.taichi"
        case .tennis:             "figure.tennis"
        case .badminton:          "figure.badminton"
        case .squash:             "figure.squash"
        case .racquetball:        "figure.racquetball"
        case .pickleball:         "figure.pickleball"
        case .tableTennis:        "figure.table.tennis"
        case .track:              "figure.track.and.field"
        case .running:            "figure.run"
        case .gymnastics:         "figure.gymnastics"
        case .dance:              "figure.dance"
        case .weightlifting:      "figure.strengthtraining.traditional"
        case .cycling:            "figure.outdoor.cycle"
        case .climbing:           "figure.climbing"
        case .golf:               "figure.golf"
        case .equestrian:         "figure.equestrian.sports"
        case .archery:            "figure.archery"
        case .bowling:            "figure.bowling"
        case .skateboarding:      "figure.skateboarding"
        case .hockeyRoller:       "figure.hockey"
        case .swimming:           "figure.pool.swim"
        case .openWater:          "figure.open.water.swim"
        case .rowing:             "figure.rower"
        case .sailing:            "figure.sailing"
        case .surfing:            "figure.surfing"
        case .skiing:             "figure.skiing.downhill"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .snowboarding:       "figure.snowboarding"
        case .figureSkating:      "figure.ice.skating"
        case .speedSkating:       "figure.skating"
        case .curling:            "figure.curling"
        }
    }
}

/// Graduated return-to-sport steps, after the 2022 Amsterdam consensus statement.
enum ReturnStep: Int, CaseIterable, Identifiable {
    case symptomLimited = 1, aerobic, sportSpecific, nonContact, fullContact, returnToSport

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .symptomLimited: "Everyday activity"
        case .aerobic:        "Light exercise"
        case .sportSpecific:  "Solo drills"
        case .nonContact:     "Non-contact practice"
        case .fullContact:    "Full-contact practice"
        case .returnToSport:  "Back to competition"
        }
    }

    var today: String {
        switch self {
        case .symptomLimited: "Rest and normal daily routine. No exercise."
        case .aerobic:        "Walking or a stationary bike. No drills, no contact."
        case .sportSpecific:  "Footwork and drills on your own. No contact."
        case .nonContact:     "Team practice with no sparring and no contact."
        case .fullContact:    "Full practice with contact. No competition yet."
        case .returnToSport:  "Back to full play."
        }
    }
}

enum StepState { case done, current, upcoming }

struct DayReading: Identifiable, Equatable {
    let day: Int
    /// Distance from the athlete's own baseline. 1.0 is the edge of their normal range.
    let distance: Double
    /// Biomarkers that sit further from normal than the rest that day, by catalog code.
    var lagging: [String: Double] = [:]
    /// Values measured live by the phone's camera that day, by catalog code. They replace the scripted value.
    var measured: [String: Double] = [:]
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

/// What a daily check decided: whether every biomarker was back at the athlete's normal, and the step that follows.
struct DailyOutcome {
    let clean: Bool
    let stepBefore: Int
    let stepAfter: Int
    let sentToProvider: Bool
    let reading: DayReading
    let baselineDate: String?

    /// The decision in one line, for the record saved to Health.
    var summary: String {
        if sentToProvider { return "Two checks in a row at normal. Sent to the doctor for the next step; staying on step \(stepAfter)." }
        if clean && stepAfter > stepBefore { return "Back at normal. Step \(stepAfter) unlocked from tomorrow." }
        if clean { return "Back at normal. Staying on step \(stepAfter) until a clinician signs the next one." }
        return "Not yet back at normal. Staying on step \(stepBefore)."
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
    var team: Team = .ridgeline
    var hasBaseline = true
    /// The athlete's one personal baseline, by date. It isn't tied to a team, season or sport.
    var baselineDate: String? = nil
    /// Baseline values measured live by the phone's camera, by catalog code. They replace the scripted normal.
    var measuredBaseline: [String: Double] = [:]
    /// The concussion model's input from this athlete's latest sideline check.
    var sidelineInput: ConcussionModel.Input = ConcussionModel.concussed
    var dailyChecks = 0
    /// Today's daily check is done; the next one opens tomorrow morning.
    var checkedToday = false
    /// When the athlete last took any test (baseline, daily or sideline check), and when they joined.
    var lastTest: Date? = nil
    /// What the last test was, when it wasn't the baseline or a daily check (e.g. "Sideline check cleared").
    var lastTestNote: String? = nil
    var joined: Date? = nil
    var sportsOverride: Set<Sport>? = nil
    var look: AvatarLook = .default
    var squadOverride: Squad? = nil

    var id: Int { number }
    var firstName: String { String(name.split(separator: " ").first ?? "") }
    /// This athlete's biomarkers against their own baseline. The spread is fixed per athlete so it's the same every run.
    var biomarkers: [BiomarkerSpec] {
        BiomarkerSpec.tracked.enumerated().map { k, spec in
            if let measured = measuredBaseline[spec.code] { return spec.personal(measured - spec.baseline) }
            let r = sin(Double(number * 37 + k * 101))
            return spec.personal(r * (BiomarkerSpec.spread[spec.code] ?? 0))
        }
    }

    /// Sports this athlete plays. Defaults to their team's sport until they pick more.
    var sports: Set<Sport> { sportsOverride ?? [team == .ridgeline ? .mma : .basketball] }
    var badge: String { team == .chesapeake ? "#\(number)" : "" }
    var squad: Squad { squadOverride ?? (team == .ridgeline ? .mmaYouth : .mensBasketball) }
    /// Belt for martial arts, number and position for basketball.
    var position: String {
        let tail = sport.components(separatedBy: " · ").last ?? ""
        return team == .chesapeake ? "#\(number) · \(tail)" : tail
    }

    var currentStep: Int? {
        switch status {
        case .recovering(let step), .awaitingProvider(let step): step
        default: nil
        }
    }

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

    var isReadyForProviderReview: Bool {
        guard case .recovering = status, history.count >= 2 else { return false }
        return history.suffix(2).allSatisfy { $0.distance <= 1.0 }
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
    /// The sideline check's biomarkers against the athlete's baseline (simulated values).
    static let demoInjuryDay: [Metric] = [
        Metric(name: "Fast eye movement · Follow the Dot", unit: "°/s", baseline: 452, today: 318, tolerance: 40, decimals: 0),
        Metric(name: "Eye tracking · Follow the Dot", unit: "", baseline: 0.94, today: 0.71, tolerance: 0.06, decimals: 2),
        Metric(name: "Blink rate · Hold & Look", unit: "/min", baseline: 15, today: 28, tolerance: 4, decimals: 0),
        Metric(name: "Pupil size difference · Light Response", unit: "mm", baseline: 0.2, today: 0.3, tolerance: 0.2, decimals: 1),
    ]
}

private func series(_ values: [Double]) -> [DayReading] {
    values.enumerated().map { DayReading(day: $0.offset + 1, distance: $0.element) }
}

private func event(_ when: String, _ actor: Actor, _ text: String) -> LogEvent {
    LogEvent(when: when, actor: actor, text: text)
}

extension Athlete {
    /// Every athlete with a baseline gets its date: from their roster note when it names one, otherwise their first recorded one.
    static let sample: [Athlete] = rawSample.map { a in
        var copy = a
        if copy.hasBaseline, copy.baselineDate == nil {
            copy.baselineDate = copy.detail.hasPrefix("Baseline ") ? String(copy.detail.dropFirst("Baseline ".count)) : "Aug 12"
        }
        Athlete.vary(&copy)
        return copy
    }

    private static let rawSample: [Athlete] = [
        // Ridgeline Academy youth team
        Athlete(number: 51, name: "Priya Nair", sport: "Ridgeline Academy · Yellow belt",
                status: .recovering(step: 2), detail: "Day 4 · step 2 of 6",
                history: series([2.6, 2.2, 1.6]),
                events: [
                    event("Day 0", .coach, "Removed from play after sideline check. Model 0.75: 3 of 4 domains flagged."),
                    event("Day 1", .provider, "Evaluation recorded by E. Ruiz, MD. Begin step 1."),
                    event("Day 2", .system, "Daily check: 3 biomarkers below normal. Step 2."),
                    event("Day 3", .system, "Daily check: 2 biomarkers below normal. Holding step 2."),
                ],
                team: .ridgeline, look: AvatarLook(skin: 0xC98E62, hair: .long, hairColor: 0x1E1A1A, kit: .gi(belt: Belt.yellow), backdrop: 0xDDEFEB)),
        Athlete(number: 52, name: "Maya Reyes", sport: "Ridgeline Academy · Orange belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline, look: AvatarLook(skin: 0xE8B48F, hair: .ponytail, hairColor: 0x3B2618, kit: .gi(belt: Belt.orange), backdrop: 0xDDEFEB)),
        Athlete(number: 53, name: "Leo Kowalski", sport: "Ridgeline Academy · Green belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline, look: AvatarLook(skin: 0xF5D3B3, hair: .short, hairColor: 0xC99A4B, kit: .gi(belt: Belt.yellow), backdrop: 0xDDEFEB)),
        Athlete(number: 54, name: "Casey Lin", sport: "Ridgeline Academy · White belt",
                status: .baselineSet, detail: "No baseline yet", team: .ridgeline, hasBaseline: false, look: AvatarLook(skin: 0xEBC5A0, hair: .short, hairColor: 0x1E1A1A, kit: .gi(belt: Belt.white), backdrop: 0xDDEFEB)),
        Athlete(number: 55, name: "Ethan Park", sport: "Ridgeline Academy · Blue belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline),
        Athlete(number: 56, name: "Amara Okoye", sport: "Ridgeline Academy · Yellow belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline),
        Athlete(number: 57, name: "Diego Ramirez", sport: "Ridgeline Academy · Orange belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline),
        Athlete(number: 58, name: "Hana Sato", sport: "Ridgeline Academy · Yellow belt",
                status: .baselineSet, detail: "Baseline Aug 18", team: .ridgeline),
        Athlete(number: 60, name: "Fatima Khan", sport: "Ridgeline Academy · Blue belt",
                status: .baselineSet, detail: "Baseline Sep 4", team: .ridgeline),
        // Chesapeake State men's basketball
        Athlete(number: 3, name: "Jalen Brooks", sport: "Men’s basketball · Guard",
                status: .baselineSet, detail: "Baseline not recorded", team: .chesapeake, hasBaseline: false, look: AvatarLook(skin: 0x5A3825, hair: .buzz, hairColor: 0x141414, kit: .jersey(number: 3, color: 0x13294B, trim: 0xF2A900), backdrop: 0xE3E8F2)),
        Athlete(number: 34, name: "Devon Price", sport: "Men’s basketball · Forward",
                status: .flagged, detail: "Removed from play 9:42 PM",
                injuryMetrics: Metric.demoInjuryDay,
                events: [event("9:42 PM", .coach, "Removed from play after sideline check. Model 0.75: 3 of 4 domains flagged.")],
                team: .chesapeake, look: AvatarLook(skin: 0x7A4A2E, hair: .afro, hairColor: 0x141414, kit: .jersey(number: 34, color: 0x13294B, trim: 0xF2A900), backdrop: 0xE3E8F2)),
        Athlete(number: 11, name: "Luis Ortega", sport: "Men’s basketball · Guard",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake, look: AvatarLook(skin: 0xC98E62, hair: .curly, hairColor: 0x1E1A1A, kit: .jersey(number: 11, color: 0x13294B, trim: 0xF2A900), backdrop: 0xE3E8F2)),
        Athlete(number: 22, name: "Sam Tran", sport: "Men’s basketball · Center",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake, look: AvatarLook(skin: 0xEBC5A0, hair: .short, hairColor: 0x1E1A1A, kit: .jersey(number: 22, color: 0x13294B, trim: 0xF2A900), backdrop: 0xE3E8F2)),
        Athlete(number: 44, name: "Eli Becker", sport: "Men’s basketball · Forward",
                status: .providerSignedOff(by: "T. Okafor, MD"), detail: "Sign-off recorded day 11",
                history: series([2.7, 2.1, 1.5, 1.1, 0.9, 0.7]),
                events: [
                    event("Day 0", .coach, "Removed from play after sideline check."),
                    event("Day 11", .provider, "Return-to-play sign-off recorded by T. Okafor, MD."),
                ],
                team: .chesapeake, look: AvatarLook(skin: 0xF5D3B3, hair: .short, hairColor: 0x6B4226, kit: .jersey(number: 44, color: 0x13294B, trim: 0xF2A900), backdrop: 0xE3E8F2)),
        Athlete(number: 1, name: "Darius Webb", sport: "Men’s basketball · Guard",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 2, name: "Tomás Herrera", sport: "Men’s basketball · Guard",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 10, name: "Kofi Mensah", sport: "Men’s basketball · Forward",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 14, name: "Ryan Choi", sport: "Men’s basketball · Guard",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 15, name: "Isaiah Thompson", sport: "Men’s basketball · Forward",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 24, name: "Arjun Mehta", sport: "Men’s basketball · Forward",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        Athlete(number: 31, name: "Liam O’Connor", sport: "Men’s basketball · Center",
                status: .baselineSet, detail: "Baseline Aug 14", team: .chesapeake),
        // Ridgeline Academy teen team
        Athlete(number: 61, name: "Aiden Cho", sport: "Ridgeline Academy · Brown belt", status: .baselineSet,
                detail: "Baseline Aug 19", team: .ridgeline, squadOverride: .mmaTeen),
        Athlete(number: 62, name: "Zara Ahmed", sport: "Ridgeline Academy · Purple belt", status: .baselineSet,
                detail: "Baseline Aug 19", team: .ridgeline, squadOverride: .mmaTeen),
        Athlete(number: 63, name: "Mateo Silva", sport: "Ridgeline Academy · Blue belt", status: .recovering(step: 4),
                detail: "Day 8 · step 4 of 6", history: [DayReading(day: 1, distance: 2.5), DayReading(day: 2, distance: 1.6), DayReading(day: 3, distance: 0.9)],
                team: .ridgeline, squadOverride: .mmaTeen),
        // Chesapeake State women's basketball
        Athlete(number: 5, name: "Kayla Johnson", sport: "Women’s basketball · Guard", status: .baselineSet,
                detail: "Baseline Aug 15", team: .chesapeake, squadOverride: .womensBasketball),
        Athlete(number: 12, name: "Ana Lima", sport: "Women’s basketball · Forward", status: .baselineSet,
                detail: "Baseline Aug 15", team: .chesapeake, squadOverride: .womensBasketball),
        Athlete(number: 23, name: "Grace Kim", sport: "Women’s basketball · Center", status: .flagged,
                detail: "Removed from play today", injuryMetrics: Metric.demoInjuryDay,
                team: .chesapeake, squadOverride: .womensBasketball),
    ]
}

/// Who is signed in. Each account sees only its own app.
struct HealthLink: Equatable {
    var write: Set<String>
    var read: Set<String>
}

@Observable
final class Session {
    var account: DemoAccount? {
        didSet {
            selectedSquad = nil
            if account == nil { nameOverride = nil; athleteOverride = nil; health = nil; healthSends = [] }
        }
    }
    /// Set by registration: the name the new person typed, and their new athlete record.
    var nameOverride: String?
    var athleteOverride: Int?
    var selectedSquad: Squad?
    /// Profile photos people add on this device, kept per account for the demo session.
    private var photos: [DemoAccount: Data] = [:]
    var photo: Data? {
        get { account.flatMap { photos[$0] } }
        set { if let account { photos[account] = newValue } }
    }
    /// Apple Health: what the person allowed, and the documents saved to Health this session.
    var health: HealthLink?
    var healthSends: [String] = []
    var healthError: String?
    /// Notification and privacy switches from the account screen. Missing keys read as on.
    var settings: [String: Bool] = [:]
    /// Presenter setting: who "Continue with Apple" signs in as.
    /// Launch with `-demoAccount coach|player|doctor` (or an account id) so each demo device signs in as its own person.
    var appleAccount: DemoAccount = Session.launchAccount

    private static var launchAccount: DemoAccount {
        switch UserDefaults.standard.string(forKey: "demoAccount") ?? "" {
        case "player": .priya
        case "doctor": .okafor
        case let id: DemoAccount(rawValue: id) ?? .sid
        }
    }
    var role: Role? { account?.role }
    var athleteID: Int { athleteOverride ?? account?.athleteID ?? 51 }
    var team: Team { account?.team ?? .ridgeline }
    let providerName = "T. Okafor, MD"
}

@Observable
final class Store {
    private(set) var athletes: [Athlete] = Athlete.sample

    func athlete(_ id: Int) -> Athlete? {
        athletes.first { $0.id == id }
    }

    func athletes(on team: Team) -> [Athlete] {
        athletes.filter { $0.team == team }
    }

    func athletes(in squad: Squad) -> [Athlete] {
        athletes.filter { $0.squad == squad }
    }

    /// Registration: a new athlete joins a team with no baseline yet.
    func addAthlete(name: String, squad: Squad) -> Int {
        let id = (athletes.map(\.number).max() ?? 100) + 1
        athletes.append(Athlete(number: id, name: name.isEmpty ? "New athlete" : name,
                                sport: squad.team == .ridgeline ? "Ridgeline Academy · White belt" : "Men’s basketball · Guard",
                                status: .baselineSet, detail: "Joined today", team: squad.team,
                                hasBaseline: false, squadOverride: squad))
        return id
    }

    // Coach

    /// A sideline check measured live. Removes the athlete from play when the concussion model flags any
    /// area or the emergency rule fires; otherwise records a cleared check. Returns whether they were removed.
    @discardableResult
    func recordSidelineCheck(_ id: Int, measured: [String: Double]) -> Bool {
        guard let a = athlete(id) else { return true }
        let specs = Dictionary(uniqueKeysWithValues: a.biomarkers.map { ($0.code, $0) })
        func v(_ code: String) -> Double { measured[code] ?? specs[code]?.baseline ?? 0 }
        let input = ConcussionModel.Input(saccadeVelocity: v("BMK-00080"), pursuitGain: v("BMK-00084"),
                                          gazeStabilization: nil, blinkRate: v("BMK-00006"),
                                          pupilAsymmetry: v("BMK-00075"))
        let flags = ConcussionModel.flags(input).count
        let removed = flags > 0 || ConcussionModel.isEmergency(input)
        let p = String(format: "%.2f", ConcussionModel.probability(input))
        let metrics: [Metric] = [("BMK-00080", "Fast eye movement · Follow the Dot", 40.0),
                                 ("BMK-00084", "Eye tracking · Follow the Dot", 0.06),
                                 ("BMK-00006", "Blink rate · Hold & Look", 4.0),
                                 ("BMK-00075", "Pupil size difference · Light Response", 0.2)].compactMap { code, name, tol in
            guard let today = measured[code], let spec = specs[code] else { return nil }
            return Metric(name: name, unit: spec.unit, baseline: spec.baseline, today: today, tolerance: tol, decimals: spec.decimals)
        }
        update(id) {
            var copy = $0
            copy.sidelineInput = input
            copy.injuryMetrics = metrics
            copy.lastTest = .now
            if removed {
                copy.status = .flagged
                copy.detail = "Removed from play just now"
                copy.lastTestNote = nil
                copy.events.append(event("Just now", .coach, "Removed from play after sideline check. Model \(p): \(flags) of 4 domains flagged."))
            } else {
                copy.lastTestNote = "Sideline check cleared"
                copy.events.append(event("Just now", .coach, "Sideline check after a hit: nothing flagged. Stayed in play."))
            }
            return copy
        }
        return removed
    }

    func flag(_ id: Int) {
        update(id) {
            var copy = $0.updating(
                status: .flagged,
                detail: "Removed from play just now",
                event: event("Just now", .coach, "Removed from play after sideline check. Model 0.75: 3 of 4 domains flagged.")
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
                        event: event("Just now", .system, "Two daily checks in a row at the athlete's normal. Sent to provider for review."))
        }
    }

    // Athlete

    func recordBaseline(_ id: Int, measured: [String: Double] = [:]) {
        update(id) {
            var copy = $0.updating(status: $0.status, detail: "Baseline Oct 25",
                                   event: event("Just now", .athlete, "Baseline recorded: 3 tests captured, 1 practice. It covers every sport."))
            copy.hasBaseline = true
            copy.baselineDate = "Oct 25"
            copy.measuredBaseline = measured
            copy.lastTest = .now
            return copy
        }
    }

    /// A daily check. The first one in the demo still shows Follow the Dot away from normal; later ones are back to normal.
    /// A check at normal moves the athlete up one step (up to step 4); the provider signs before step 5.
    @discardableResult
    /// Demo script: the first daily check leaves smooth pursuit gain short of normal; later checks are clean.
    func recordDailyCheck(_ id: Int, measured: [String: Double] = [:]) -> DailyOutcome? {
        guard let a = athlete(id) else { return nil }
        let before = a.currentStep ?? 1
        let day = a.history.count + 1
        let clean: Bool
        let reading: DayReading
        if measured.isEmpty {
            // Scripted: the first check leaves pursuit gain short of normal; later checks are clean.
            clean = a.dailyChecks >= 1
            reading = clean ? DayReading(day: day, distance: 0.8)
                            : DayReading(day: day, distance: 0.8, lagging: ["BMK-00084": 1.6])
        } else {
            // Measured live: clean only if every measured biomarker is back at this athlete's normal.
            reading = DayReading(day: day, distance: 0.8, measured: measured)
            clean = a.biomarkers.allSatisfy { spec in
                guard let v = measured[spec.code] else { return true }
                return spec.isAtNormal(v) && !spec.isFlagged(v)
            }
        }
        update(id) {
            var copy = $0
            copy.dailyChecks += 1
            copy.checkedToday = true
            copy.lastTest = .now
            copy.history.append(reading)
            if clean, before < 4 {
                copy.status = .recovering(step: before + 1)
                copy.detail = "Day \(day + 1) · step \(before + 1) of 6"
                copy.events.append(event("Just now", .system, "Daily check back at normal. Moves to step \(before + 1) tomorrow."))
            } else if clean {
                copy.events.append(event("Just now", .system, "Daily check back at normal."))
            } else {
                copy.events.append(event("Just now", .system, "Daily check: smooth pursuit gain still below normal. Holding step \(before)."))
            }
            return copy
        }
        var sent = false
        if let updated = athlete(id), updated.isReadyForProviderReview, (updated.currentStep ?? 0) >= 4 {
            sendToProvider(id)
            sent = true
        }
        return DailyOutcome(clean: clean, stepBefore: before, stepAfter: athlete(id)?.currentStep ?? before,
                            sentToProvider: sent, reading: reading, baselineDate: a.baselineDate)
    }

    func setSports(_ id: Int, _ sports: Set<Sport>) {
        update(id) { var copy = $0; copy.sportsOverride = sports; return copy }
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

// MARK: - Test schedule

extension Date {
    /// A time on a day before the demo's today.
    static func demo(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: .now)) ?? .now
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// "Aug 18" in the current year, at 4 PM.
    static func demo(monthDay: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d yyyy HH:mm"
        return f.date(from: "\(monthDay) \(Calendar.current.component(.year, from: .now)) 16:00")
    }

    /// "Today, 7:40 PM", "Yesterday, 7:40 PM", "Thu, 6:05 PM" within a week, otherwise "Aug 18".
    var testStamp: String {
        let cal = Calendar.current
        let time = formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(self) { return "Today, \(time)" }
        if cal.isDateInYesterday(self) { return "Yesterday, \(time)" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: self), to: cal.startOfDay(for: .now)).day, days < 7 {
            return "\(formatted(.dateTime.weekday(.abbreviated))), \(time)"
        }
        return formatted(.dateTime.month(.abbreviated).day())
    }
}

/// Whether a test is due. Recovering athletes take the daily check every day; everyone else needs a baseline
/// once, renewed after a year. Sideline checks happen when a coach sees a hit, so they're never "due".
enum TestDue: Equatable {
    case doneToday
    case dueToday
    case overdue(days: Int)
    case baselineDue
    case baselineOverdue(days: Int)
    case waitingForProvider
    case upToDate(next: Date?)

    var isOverdue: Bool {
        switch self {
        case .overdue, .baselineOverdue: true
        default: false
        }
    }

    var needsTest: Bool {
        switch self {
        case .dueToday, .overdue, .baselineDue, .baselineOverdue: true
        default: false
        }
    }

    var kind: CheckKind {
        switch self {
        case .baselineDue, .baselineOverdue: .baseline
        default: .daily
        }
    }

    /// Short line for rosters.
    var short: String {
        switch self {
        case .doneToday:                 "Checked today"
        case .dueToday:                  "Daily check due today"
        case .overdue(let d):            "Daily check overdue · \(d) day\(d == 1 ? "" : "s")"
        case .baselineDue:               "Baseline due"
        case .baselineOverdue(let d):    "Baseline overdue · \(d) day\(d == 1 ? "" : "s")"
        case .waitingForProvider:        "Next check after provider review"
        case .upToDate:                  "Tests up to date"
        }
    }
}

extension Athlete {
    /// "Sideline check cleared · Thu, 6:45 PM" or "Last test Aug 18".
    var lastTestLine: String {
        guard let t = lastTest else { return "No tests yet" }
        return lastTestNote.map { "\($0) · \(t.testStamp)" } ?? "Last test \(t.testStamp)"
    }

    var testDue: TestDue {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func daysSince(_ d: Date?) -> Int { d.flatMap { cal.dateComponents([.day], from: cal.startOfDay(for: $0), to: today).day } ?? 0 }
        if !hasBaseline {
            let waited = daysSince(joined)
            return waited > 7 ? .baselineOverdue(days: waited - 7) : .baselineDue
        }
        switch status {
        case .recovering, .awaitingProvider:
            if checkedToday || lastTest.map(cal.isDateInToday) == true { return .doneToday }
            let missed = daysSince(lastTest) - 1
            return missed >= 1 ? .overdue(days: missed) : .dueToday
        case .flagged, .evaluationRequested:
            return .waitingForProvider
        case .baselineSet, .providerSignedOff:
            let base = baselineDate.flatMap(Date.demo(monthDay:))
            return .upToDate(next: base.flatMap { cal.date(byAdding: .year, value: 1, to: $0) })
        }
    }
}

// MARK: - Demo variety

extension Athlete {
    /// Spreads the demo across every state a roster really has: due, overdue, done today, cleared after a hit,
    /// with a provider, recovering at different steps, signed off. Dates are relative to the demo's today.
    static func vary(_ a: inout Athlete) {
        func cleared(_ days: Int, _ h: Int, _ m: Int, by: String = "Coach") {
            a.lastTest = .demo(daysAgo: days, hour: h, minute: m)
            a.lastTestNote = "Sideline check cleared"
            a.events.append(event(days == 0 ? "Today" : "\(days)d ago", .coach, "Sideline check after a hit: all 5 biomarkers at baseline. Stayed in play."))
        }
        func recovering(_ step: Int, _ readings: [Double], lastDaysAgo: Int, h: Int, m: Int, doneToday: Bool = false) {
            a.status = .recovering(step: step)
            a.history = series(readings)
            a.detail = "Day \(readings.count + 1) · step \(step) of 6"
            a.lastTest = .demo(daysAgo: lastDaysAgo, hour: h, minute: m)
            a.checkedToday = doneToday
            a.dailyChecks = doneToday ? 1 : 0
            a.events = [event("Day 0", .coach, "Removed from play after sideline check.")]
                + readings.indices.dropFirst().map { event("Day \($0)", .system, "Daily check. Step \(min($0, step)).") }
        }
        switch a.number {
        // Ridgeline Academy youth
        case 51: a.lastTest = .demo(daysAgo: 1, hour: 19, minute: 40)                          // Priya: daily check due today
        case 52: a.baselineDate = "Sep 6"; cleared(7, 17, 20); a.sportsOverride = [.mma, .soccer]
        case 53:                                                                               // Leo: signed off, back in play
            a.baselineDate = "Aug 30"
            a.status = .providerSignedOff(by: "E. Ruiz, MD")
            a.history = series([2.5, 1.8, 1.2, 0.9, 0.8, 0.75])
            a.lastTest = .demo(daysAgo: 5, hour: 18, minute: 10)
            a.detail = "Signed off Oct 20"
            a.events = [event("Oct 12", .coach, "Removed from play after sideline check."),
                        event("Oct 20", .provider, "Return-to-play sign-off recorded by E. Ruiz, MD.")]
            a.sportsOverride = [.mma, .basketball]
        case 54: a.joined = .demo(daysAgo: 10, hour: 9, minute: 0)                             // Casey: baseline overdue
        case 55:                                                                               // Ethan: with provider after a tournament hit
            a.baselineDate = "Aug 24"
            a.status = .evaluationRequested
            a.injuryMetrics = Metric.demoInjuryDay
            a.lastTest = .demo(daysAgo: 1, hour: 14, minute: 15)
            a.detail = "Removed yesterday 2:15 PM"
            a.events = [event("Yesterday", .coach, "Removed from play at the regional tournament. Model 0.75: 3 of 4 domains flagged."),
                        event("Yesterday", .coach, "Evaluation requested from E. Ruiz, MD.")]
        case 56: a.baselineDate = "Aug 18"; a.sportsOverride = [.mma, .gymnastics]
        case 57: a.baselineDate = "Sep 2"; recovering(4, [2.4, 1.9, 1.4, 1.0, 0.85], lastDaysAgo: 0, h: 7, m: 5, doneToday: true)
        case 58: a.baselineDate = "Sep 12"; cleared(3, 18, 45)
        // Ridgeline Academy teens
        case 61: a.baselineDate = "Aug 19"; a.lastTest = .demo(monthDay: "Aug 19")
        case 62: a.baselineDate = "Aug 19"; cleared(1, 19, 30); a.sportsOverride = [.mma, .wrestling]
        case 63: a.lastTest = .demo(daysAgo: 3, hour: 18, minute: 5)                            // Mateo: daily check overdue
        // Chesapeake State men
        case 3:  a.joined = .demo(daysAgo: 2, hour: 9, minute: 0)                              // Jalen: baseline due
        case 34: a.lastTest = .demo(daysAgo: 0, hour: 21, minute: 42)                          // Devon: removed tonight
        case 11: a.baselineDate = "Aug 14"; cleared(4, 20, 50)
        case 22: a.baselineDate = "Aug 21"; recovering(3, [2.5, 2.0, 1.6], lastDaysAgo: 2, h: 8, m: 30)   // Sam: overdue
        case 44: a.lastTest = .demo(daysAgo: 4, hour: 16, minute: 30)                          // Eli: signed off
        case 1:                                                                                // Darius: two clean checks, with provider
            a.baselineDate = "Aug 14"
            recovering(4, [2.3, 1.6, 1.1, 0.85, 0.8], lastDaysAgo: 0, h: 8, m: 10, doneToday: true)
            a.status = .awaitingProvider(step: 4)
            a.events.append(event("Today", .system, "Two checks in a row at baseline. Report sent to T. Okafor, MD."))
        case 2:  a.baselineDate = "Sep 2"
        case 10: a.baselineDate = "Aug 14"; a.sportsOverride = [.basketball, .track]
        case 14: a.baselineDate = "Aug 28"; cleared(2, 21, 5)
        case 15: a.baselineDate = "Aug 22"
        case 24: a.baselineDate = "Sep 9"; recovering(1, [2.6], lastDaysAgo: 1, h: 10, m: 0)  // Arjun: step 1, due today
        case 31: a.baselineDate = "Sep 9"; a.sportsOverride = [.basketball, .volleyball]
        // Chesapeake State women
        case 12: a.baselineDate = "Aug 15"; cleared(5, 19, 15)
        case 23: a.lastTest = .demo(daysAgo: 0, hour: 17, minute: 15)                          // Grace: removed today
        default: break
        }
        if a.lastTest == nil, a.hasBaseline { a.lastTest = a.baselineDate.flatMap(Date.demo(monthDay:)) }
    }
}
