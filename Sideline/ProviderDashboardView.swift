import SwiftUI

/// Queue of cases a provider can act on. Recovering athletes are visible but need no action.
struct ProviderDashboardView: View {
    @Environment(Store.self) private var store
    @Environment(Session.self) private var session

    private struct Queue: Identifiable {
        let title: String
        let tint: Color
        let athletes: [Athlete]
        var id: String { title }
    }

    private var queues: [Queue] {
        let all = store.athletes
        let candidates = [
            Queue(title: "Evaluation requested", tint: Palette.flag,
                  athletes: all.filter { $0.status == .evaluationRequested }),
            Queue(title: "Return review", tint: Palette.flag,
                  athletes: all.filter { if case .awaitingProvider = $0.status { true } else { false } }),
            Queue(title: "In recovery", tint: Palette.muted,
                  athletes: all.filter { if case .recovering = $0.status { true } else { false } }),
            Queue(title: "Sign-off on file", tint: Palette.steady,
                  athletes: all.filter { if case .providerSignedOff = $0.status { true } else { false } }),
        ]
        return candidates.filter { !$0.athletes.isEmpty }
    }

    private var actionCount: Int {
        store.athletes.filter {
            if $0.status == .evaluationRequested { return true }
            if case .awaitingProvider = $0.status { return true }
            return false
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    RoleBar(title: "Provider view")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Case queue").font(Typeface.display(36)).foregroundStyle(Palette.ink)
                        Text(session.providerName + " · Sports medicine")
                            .font(Typeface.body)
                            .foregroundStyle(Palette.muted)
                        HashRule()
                        Text(actionCount == 0 ? "Nothing waiting on you." : "\(actionCount) waiting on your decision.")
                            .font(Typeface.mono(14, weight: .semibold))
                            .foregroundStyle(actionCount == 0 ? Palette.muted : Palette.flag)
                    }
                    ForEach(queues) { queue in section(queue) }
                    Text("You decide each step. Sideline records your decision and the measurements behind it, and never clears an athlete.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 24)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationDestination(for: Int.self) { ProviderCaseView(athleteID: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func section(_ queue: Queue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("\(queue.title) · \(queue.athletes.count)", color: queue.tint).padding(.bottom, 10)
            ForEach(queue.athletes) { athlete in
                NavigationLink(value: athlete.id) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(athlete.number)")
                            .font(Typeface.mono(22, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 40, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(athlete.name).font(Typeface.display(20)).foregroundStyle(Palette.ink)
                            Text(athlete.sport).font(Typeface.caption).foregroundStyle(Palette.muted)
                            Text(athlete.detail).font(Typeface.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 8)
                        StatusTag(status: athlete.status)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }
}

struct ProviderCaseView: View {
    let athleteID: Int

    @Environment(Store.self) private var store
    @Environment(Session.self) private var session
    @State private var confirmSignOff = false

    var body: some View {
        if let athlete = store.athlete(athleteID) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header(athlete)
                    request(athlete)
                    if !athlete.injuryMetrics.isEmpty { injuryDay(athlete) }
                    if !athlete.history.isEmpty { RecoveryChart(history: athlete.history) }
                    if athlete.showsSteps { StepsLadder(athlete: athlete) }
                    EventTimeline(events: athlete.events)
                    decision(athlete)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 20)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Record return-to-play sign-off for \(athlete.name)?",
                isPresented: $confirmSignOff,
                titleVisibility: .visible
            ) {
                Button("Record sign-off") { store.signOff(athlete.id, by: session.providerName) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This records that you evaluated the athlete and are qualified under your state's law to make this decision.")
            }
        }
    }

    private func header(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(athlete.number)").font(Typeface.mono(44, weight: .bold)).foregroundStyle(Palette.muted)
                Text(athlete.name).font(Typeface.display(34)).foregroundStyle(Palette.ink)
            }
            Text(athlete.sport).font(Typeface.body).foregroundStyle(Palette.muted)
            HashRule()
        }
    }

    private func request(_ athlete: Athlete) -> some View {
        let copy = requestCopy(athlete.status)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(copy.eyebrow, color: copy.tint)
            Text(copy.body).font(Typeface.body).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .overlay(alignment: .leading) { Rectangle().fill(copy.tint).frame(width: 4) }
    }

    private func injuryDay(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Injury-day check vs. own baseline").padding(.bottom, 8)
            ForEach(athlete.injuryMetrics) { metric in
                MetricRow(metric: metric)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
            Text("Measurements only, simulated here. They support your evaluation; they are not a diagnosis.")
                .font(Typeface.caption)
                .foregroundStyle(Palette.muted)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private func decision(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Your decision")
            switch athlete.status {
            case .evaluationRequested:
                Button("Record evaluation · begin step 1") {
                    store.beginRecovery(athlete.id, by: session.providerName)
                }
                .buttonStyle(SolidButton())
                Button("Keep out of activity · further workup") {
                    store.addProviderNote(athlete.id, "Kept out of activity pending further workup.")
                }
                .buttonStyle(OutlineButton())
            case .awaitingProvider(let step):
                if step < 6 {
                    Button("Approve step \(step + 1)") {
                        store.approveNextStep(athlete.id, by: session.providerName)
                    }
                    .buttonStyle(SolidButton())
                }
                Button("Hold at step \(step)") { store.hold(athlete.id) }.buttonStyle(OutlineButton())
                Button("Record return-to-play sign-off") { confirmSignOff = true }
                    .buttonStyle(SolidButton(tint: Palette.flag))
            case .recovering:
                Text("No review requested. Sideline asks for your review after three consecutive days inside the athlete's own range.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.muted)
            case .providerSignedOff(let by):
                Text("Sign-off by \(by) is on file. Sideline keeps your record; it does not grant clearance.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.muted)
            default:
                Text("This athlete has not been sent to a provider yet.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func requestCopy(_ status: RecoveryStatus) -> (eyebrow: String, body: String, tint: Color) {
        switch status {
        case .evaluationRequested:
            ("Evaluation requested", "Coach removed this athlete from play after a sideline check and is asking for your evaluation.", Palette.flag)
        case .awaitingProvider(let step):
            ("Return review", "Readings have stayed inside the athlete's own range for three days at step \(step). Your decision is needed.", Palette.flag)
        case .recovering(let step):
            ("In recovery", "Athlete is on step \(step) of 6 under your earlier direction.", Palette.muted)
        case .providerSignedOff:
            ("Closed", "A return-to-play sign-off is on file for this injury.", Palette.steady)
        default:
            ("Not sent", "This case has not been sent for review.", Palette.muted)
        }
    }
}
