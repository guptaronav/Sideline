import Foundation
import HealthKit
import Observation

/// Real reads from Apple Health: last night's sleep, heart rate variability, resting heart rate and recent
/// workouts, each with the athlete's usual over the past 14 days. A value Health doesn't have stays nil and
/// the screen says so; nothing is filled in.
@MainActor
@Observable
final class HealthReader {
    static let shared = HealthReader()

    struct Workout: Identifiable {
        let name: String
        let symbol: String
        let minutes: Int
        let avgHR: Int?
        let start: Date
        var id: Date { start }

        var when: String { start.testStamp }
    }

    struct Readings {
        var sleepLastNight: TimeInterval?
        var sleepUsual: TimeInterval?
        var hrv: Double?
        var hrvUsual: Double?
        var restingHR: Double?
        var restingUsual: Double?
        var workouts: [Workout] = []
    }

    private(set) var readings = Readings()
    private(set) var loading = false
    private(set) var loadedAt: Date?

    private var store: HKHealthStore { HealthBridge.store }
    private static let usualDays = 14

    /// Loads everything Health will share. Safe to call again; each call replaces the readings.
    func refresh() async {
        guard HealthBridge.isAvailable else { return }
        loading = true
        defer { loading = false }
        var r = Readings()
        async let sleep = sleepNights()
        async let hrv = latestAndAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let resting = latestAndAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let workouts = recentWorkouts(limit: 2)

        let nights = await sleep
        r.sleepLastNight = nights.last.flatMap { Calendar.current.isDateInToday($0.day) ? $0.asleep : nil }
        let earlier = nights.filter { !Calendar.current.isDateInToday($0.day) }.map(\.asleep)
        r.sleepUsual = earlier.isEmpty ? nil : earlier.reduce(0, +) / Double(earlier.count)
        (r.hrv, r.hrvUsual) = await hrv
        (r.restingHR, r.restingUsual) = await resting
        r.workouts = await workouts
        readings = r
        loadedAt = .now
    }

    // MARK: Sleep

    private struct Night { let day: Date; let asleep: TimeInterval }

    /// Asleep time per night for the past 14 days. A night belongs to the day it ends on. iPhone and Apple Watch
    /// often both record the same night, so overlapping intervals are merged before summing.
    private func sleepNights() async -> [Night] {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .day, value: -Self.usualDays, to: .now) ?? .now
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: .now))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        var byDay: [Date: [(Date, Date)]] = [:]
        for s in samples where asleep.contains(s.value) {
            byDay[Calendar.current.startOfDay(for: s.endDate), default: []].append((s.startDate, s.endDate))
        }
        return byDay.keys.sorted().map { day in
            var total: TimeInterval = 0
            var current: (Date, Date)?
            for iv in byDay[day]!.sorted(by: { $0.0 < $1.0 }) {
                if let c = current, iv.0 <= c.1 {
                    current = (c.0, max(c.1, iv.1))
                } else {
                    if let c = current { total += c.1.timeIntervalSince(c.0) }
                    current = iv
                }
            }
            if let c = current { total += c.1.timeIntervalSince(c.0) }
            return Night(day: day, asleep: total)
        }
    }

    // MARK: Heart

    /// The most recent value and the 14-day average, in `unit`.
    private func latestAndAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> (Double?, Double?) {
        let type = HKQuantityType(id)
        let latestQuery = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type)],
                                                  sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        let latest = (try? await latestQuery.result(for: store))?.first?.quantity.doubleValue(for: unit)
        let start = Calendar.current.date(byAdding: .day, value: -Self.usualDays, to: .now) ?? .now
        let avgQuery = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: .now)),
            options: .discreteAverage)
        let average = (try? await avgQuery.result(for: store))??.averageQuantity()?.doubleValue(for: unit)
        return (latest, average)
    }

    // MARK: Workouts

    private func recentWorkouts(limit: Int) async -> [Workout] {
        let query = HKSampleQueryDescriptor(predicates: [.workout()],
                                            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: limit)
        guard let workouts = try? await query.result(for: store) else { return [] }
        var out: [Workout] = []
        for w in workouts {
            let hrType = HKQuantityType(.heartRate)
            let avgQuery = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: hrType, predicate: HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate)),
                options: .discreteAverage)
            let avg = (try? await avgQuery.result(for: store))??.averageQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute()))
            let (name, symbol) = Self.describe(w.workoutActivityType)
            out.append(Workout(name: name, symbol: symbol, minutes: Int((w.duration / 60).rounded()),
                               avgHR: avg.map { Int($0.rounded()) }, start: w.startDate))
        }
        return out
    }

    private static func describe(_ type: HKWorkoutActivityType) -> (String, String) {
        switch type {
        case .walking:                 ("Walk", "figure.walk")
        case .running:                 ("Run", "figure.run")
        case .cycling:                 ("Cycling", "figure.outdoor.cycle")
        case .basketball:              ("Basketball", "figure.basketball")
        case .martialArts:             ("Martial arts", "figure.martial.arts")
        case .boxing, .kickboxing:     ("Boxing", "figure.boxing")
        case .wrestling:               ("Wrestling", "figure.wrestling")
        case .soccer:                  ("Soccer", "figure.soccer")
        case .swimming:                ("Swim", "figure.pool.swim")
        case .yoga:                    ("Yoga", "figure.yoga")
        case .highIntensityIntervalTraining: ("HIIT", "figure.highintensity.intervaltraining")
        case .traditionalStrengthTraining, .functionalStrengthTraining: ("Strength", "figure.strengthtraining.traditional")
        case .elliptical:              ("Elliptical", "figure.elliptical")
        case .rowing:                  ("Rowing", "figure.rower")
        case .hiking:                  ("Hike", "figure.hiking")
        default:                       ("Workout", "figure.mixed.cardio")
        }
    }
}

extension TimeInterval {
    /// "7 h 05 m".
    var sleepText: String {
        let m = Int((self / 60).rounded())
        return "\(m / 60) h " + String(format: "%02d m", m % 60)
    }
}
