import SwiftUI
import OSLog

// Apple Health. Push is real HealthKit (HealthBridge): the iOS permission sheet, then each check and the baseline
// saved to Health as a clinical document carrying the five biomarkers. Health has no native type for them.
// Pull is real HealthKit too (HealthReader): sleep, heart rate variability, resting heart rate and workouts.
// Anything Health doesn't have shows as "No data in Health", never a made-up value.

enum HealthColor {
    /// The Health app's own heart color, used only for Apple Health identity.
    static let heart = Color(hex: 0xFF2D55)
}

/// The Health app mark: a white tile with the pink heart.
struct HealthMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(HealthColor.heart)
            .frame(width: size, height: size)
            .background(.white, in: RoundedRectangle(cornerRadius: size * 0.24))
            .overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(Palette.rule, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Return-to-sport step 2 keeps aerobic work to about 70% of maximum heart rate (Tanaka: 208 − 0.7 × age).
func stepTwoHeartRateCap(_ athlete: Athlete) -> Int {
    let age: Double = athlete.team == .chesapeake ? 20 : athlete.squad == .mmaTeen ? 15 : 13
    return Int((208 - 0.7 * age) * 0.7)
}

/// "No data in Health" for anything Health can't supply.
private let noData = "No data"

// MARK: - Connect sheet

/// Sideline's own step before the iOS Health sheet: what it sends, what it reads. Continue hands off to iOS.
struct HealthAccessSheet: View {
    @Environment(Session.self) private var session
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var write: Set<String> = []
    @State private var read: Set<String> = []
    @State private var working = false

    static let writes = [("Check results", "doc.text.fill", Color(hex: 0x5856D6))]
    static let reads = [("Sleep", "bed.double.fill", Color(hex: 0x5AC8FA)),
                        ("Heart Rate Variability", "waveform.path.ecg", HealthColor.heart),
                        ("Resting Heart Rate", "heart.fill", HealthColor.heart),
                        ("Workouts", "figure.run", Color(hex: 0x34C759))]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        HealthMark(size: 64)
                        Text("Connect Apple Health").font(.system(size: 24, weight: .bold))
                        Text("Choose what Sideline sends to Health and what it reads. iOS asks you to confirm next.")
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                Section {
                    ForEach(Self.writes, id: \.0) { row($0, in: $write) }
                } header: {
                    Text("Send to Health")
                } footer: {
                    Text("Each check and your baseline, as a clinical document with your five biomarkers, their thresholds and the step decision.")
                }
                Section {
                    ForEach(Self.reads, id: \.0) { row($0, in: $read) }
                } header: {
                    Text("Read from Health")
                } footer: {
                    Text("Workouts show whether activity stays within your return-to-sport step. Sleep and heart rate give recovery context.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not Now") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Continue") { Task { await connect() } }
                            .fontWeight(.semibold)
                            .disabled(write.isEmpty && read.isEmpty)
                    }
                }
            }
            .onAppear {
                write = session.health?.write ?? Set(Self.writes.map(\.0))
                read = session.health?.read ?? Set(Self.reads.map(\.0))
            }
        }
    }

    /// iOS shows its Health sheet; whatever writing it allowed, the baseline goes to Health straight away.
    private func connect() async {
        working = true
        await HealthBridge.requestAccess(write: !write.isEmpty, read: !read.isEmpty)
        let canWrite = HealthBridge.canWrite
        session.health = HealthLink(write: canWrite ? write : [], read: read)
        if !read.isEmpty { await HealthReader.shared.refresh() }
        if canWrite, let athlete = store.athlete(session.athleteID), athlete.hasBaseline {
            await HealthPush.baseline(athlete, session: session)
        }
        working = false
        dismiss()
    }

    private func row(_ item: (String, String, Color), in set: Binding<Set<String>>) -> some View {
        Toggle(isOn: Binding(
            get: { set.wrappedValue.contains(item.0) },
            set: { on in if on { set.wrappedValue.insert(item.0) } else { set.wrappedValue.remove(item.0) } }
        )) {
            HStack(spacing: 12) {
                IconTile(symbol: item.1, tint: item.2, size: 28)
                Text(item.0)
            }
        }
        .tint(Color(hex: 0x34C759))
    }
}

// MARK: - Apple Health screen (from the account screen)

struct AppleHealthView: View {
    @Environment(Session.self) private var session
    @Environment(Store.self) private var store
    @State private var showAccess = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    HealthMark(size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Health").font(.system(size: 20, weight: .semibold))
                        Text(session.health == nil ? "Not connected" : "Connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(session.health == nil ? Palette.muted : Color(hex: 0x34C759))
                    }
                }
                .padding(.vertical, 4)
            }
            if let link = session.health, let athlete = store.athlete(session.athleteID) {
                connected(link, athlete)
            } else {
                Section {
                    Text("Save every check and your baseline to Health, and use your sleep, heart rate and workouts as recovery context. Sideline never asks how you feel.")
                        .font(Typeface.body)
                    Button { showAccess = true } label: {
                        Text("Connect Apple Health").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidButton())
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                }
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .task { if session.health?.read.isEmpty == false { await HealthReader.shared.refresh() } }
        .refreshable { await HealthReader.shared.refresh() }
        .sheet(isPresented: $showAccess) { HealthAccessSheet() }
    }

    @ViewBuilder
    private func connected(_ link: HealthLink, _ athlete: Athlete) -> some View {
        let r = HealthReader.shared.readings
        let cap = stepTwoHeartRateCap(athlete)
        Section {
            if let error = session.healthError {
                Text("Couldn't save to Health: \(error)").font(Typeface.caption).foregroundStyle(Palette.flag)
            }
            if link.write.isEmpty {
                Text("Writing is off. Turn on Clinical Documents in Manage access.").foregroundStyle(Palette.muted)
            } else {
                if session.healthSends.isEmpty {
                    Text("Your next check is saved here.").foregroundStyle(Palette.muted)
                }
                ForEach(session.healthSends.reversed(), id: \.self) { title in
                    HStack(spacing: 12) {
                        IconTile(symbol: "doc.text.fill", tint: Color(hex: 0x5856D6), size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.system(size: 15, weight: .semibold))
                            Text("Clinical document · in Health").font(Typeface.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: Icon.check).foregroundStyle(Color(hex: 0x34C759))
                    }
                }
            }
        } header: {
            Text("Sent to Health")
        } footer: {
            Text("Each one is a clinical document with your five biomarkers, their thresholds, your baseline date and the step decision. Open Health › Browse › Clinical Documents to see them.")
        }
        if !link.read.isEmpty {
            Section("From Health") {
                if link.read.contains("Sleep") { stat("bed.double.fill", Color(hex: 0x5AC8FA), "Sleep last night", r.sleepLastNight?.sleepText, r.sleepUsual.map { "Usual \($0.sleepText)" }) }
                if link.read.contains("Heart Rate Variability") { stat("waveform.path.ecg", HealthColor.heart, "Heart rate variability", r.hrv.map { "\(Int($0.rounded())) ms" }, r.hrvUsual.map { "Usual \(Int($0.rounded())) ms" }) }
                if link.read.contains("Resting Heart Rate") { stat("heart.fill", HealthColor.heart, "Resting heart rate", r.restingHR.map { "\(Int($0.rounded())) bpm" }, r.restingUsual.map { "Usual \(Int($0.rounded())) bpm" }) }
            }
            if link.read.contains("Workouts") {
                Section {
                    if r.workouts.isEmpty { Text("No workouts in Health").foregroundStyle(Palette.muted) }
                    ForEach(r.workouts) { HealthWorkoutRow(workout: $0, cap: cap, step: athlete.currentStep) }
                } header: {
                    Text("Workouts")
                } footer: {
                    if let step = athlete.currentStep, step <= 2 {
                        Text("Step \(step) keeps exercise under about 70% of your maximum heart rate: \(cap) bpm.")
                    }
                }
            }
        }
        Section {
            Button("Manage access") { showAccess = true }
            Button("Disconnect", role: .destructive) { session.health = nil }
        }
    }

    private func stat(_ symbol: String, _ tint: Color, _ title: String, _ value: String?, _ usual: String?) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: tint, size: 28)
            Text(title)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value ?? noData).font(.system(size: 16, weight: value == nil ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(value == nil ? Palette.muted : Palette.ink)
                if let usual { Text(usual).font(Typeface.caption).foregroundStyle(Palette.muted) }
            }
        }
    }

}

struct HealthWorkoutRow: View {
    let workout: HealthReader.Workout
    let cap: Int
    let step: Int?

    var body: some View {
        let within = (workout.avgHR ?? 0) <= cap
        HStack(spacing: 12) {
            IconTile(symbol: workout.symbol, tint: Color(hex: 0x34C759), size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(workout.name) · \(workout.minutes) min").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(workout.avgHR.map { "\(workout.when) · avg \($0) bpm" } ?? workout.when).font(Typeface.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
            if let step, step <= 2, workout.avgHR != nil {
                Text(within ? "Within step \(step)" : "Above step \(step)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(within ? Palette.steady : Palette.flag)
            }
        }
    }
}

// MARK: - Home card

/// On the athlete's home: what Health says about recovery, or a prompt to connect it.
struct HealthCard: View {
    let athlete: Athlete
    @Environment(Session.self) private var session
    @State private var showAccess = false

    var body: some View {
        Group {
            if let link = session.health, !link.read.isEmpty {
                connected(link)
            } else {
                Button { showAccess = true } label: {
                    HStack(spacing: 12) {
                        HealthMark(size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Apple Health").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text("Save your checks to Health and add sleep and workouts to your recovery.")
                                .font(Typeface.caption).foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
                    }
                    .panel()
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAccess) { HealthAccessSheet() }
    }

    private func connected(_ link: HealthLink) -> some View {
        let r = HealthReader.shared.readings
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HealthMark(size: 22)
                Eyebrow("From Apple Health")
            }
            HStack(alignment: .top, spacing: 0) {
                if link.read.contains("Sleep") { tile("Sleep", r.sleepLastNight?.sleepText, r.sleepUsual.map { "usual \($0.sleepText)" }) }
                if link.read.contains("Heart Rate Variability") { tile("HRV", r.hrv.map { "\(Int($0.rounded())) ms" }, r.hrvUsual.map { "usual \(Int($0.rounded()))" }) }
                if link.read.contains("Resting Heart Rate") { tile("Resting HR", r.restingHR.map { "\(Int($0.rounded())) bpm" }, r.restingUsual.map { "usual \(Int($0.rounded()))" }) }
            }
            if link.read.contains("Workouts") {
                Rectangle().fill(Palette.rule).frame(height: 1)
                if let latest = r.workouts.first {
                    HealthWorkoutRow(workout: latest, cap: stepTwoHeartRateCap(athlete), step: athlete.currentStep)
                } else {
                    Text("No workouts in Health").font(Typeface.caption).foregroundStyle(Palette.muted)
                }
            }
        }
        .panel()
        .task { await HealthReader.shared.refresh() }
    }

    private func tile(_ title: String, _ value: String?, _ usual: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Typeface.caption).foregroundStyle(Palette.muted)
            Text(value ?? noData).font(.system(size: value == nil ? 15 : 18, weight: value == nil ? .regular : .semibold, design: .rounded))
                .foregroundStyle(value == nil ? Palette.muted : Palette.ink)
            if let usual { Text(usual).font(.system(size: 11)).foregroundStyle(Palette.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Saved to Apple Health" under a check result, when writing is on.
struct SavedToHealth: View {
    @Environment(Session.self) private var session

    var body: some View {
        if let link = session.health, !link.write.isEmpty {
            HStack(spacing: 10) {
                HealthMark(size: 24)
                Text("Saved to Apple Health as a clinical document").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
            }
        }
    }
}

/// Builds the biomarker rows for a check and saves them to Health. Records the send on success only.
enum HealthPush {
    private static let log = Logger(subsystem: "com.oculodx.sideline", category: "health")

    @MainActor
    static func daily(_ athlete: Athlete, outcome: DailyOutcome, decision: String, session: Session) async {
        let rows = athlete.biomarkers.map { spec in
            let v = spec.value(outcome.reading)
            return HealthBridge.Row(name: spec.name, code: spec.code, today: spec.format(v), baseline: spec.format(spec.baseline),
                                    threshold: spec.thresholdText,
                                    status: spec.isFlagged(v) ? "Past threshold" : spec.isAtNormal(v) ? "At normal" : "Below normal")
        }
        await save("Sideline daily check · day \(outcome.reading.day)", athlete, rows, decision, session)
    }

    @MainActor
    static func baseline(_ athlete: Athlete, session: Session) async {
        let rows = athlete.biomarkers.map { spec in
            HealthBridge.Row(name: spec.name, code: spec.code, today: spec.format(spec.baseline), baseline: spec.format(spec.baseline),
                             threshold: spec.thresholdText, status: "Baseline")
        }
        await save("Sideline baseline · \(athlete.baselineDate ?? "today")", athlete, rows,
                   "Personal baseline. It covers every sport this athlete plays.", session)
    }

    @MainActor
    private static func save(_ title: String, _ athlete: Athlete, _ rows: [HealthBridge.Row], _ decision: String, _ session: Session) async {
        guard let link = session.health, !link.write.isEmpty else { return }
        do {
            try await HealthBridge.saveCheck(title: title, athlete: athlete, rows: rows, decision: decision)
            session.healthSends.append(title)
            log.notice("Saved to Health: \(title, privacy: .public)")
        } catch {
            session.healthError = error.localizedDescription
            log.error("Health save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}