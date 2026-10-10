import SwiftUI

struct AthleteView: View {
    let athleteID: Int

    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var showCheck = false
    @State private var showReport = false

    var body: some View {
        if let athlete = store.athlete(athleteID) {
            content(athlete)
        }
    }

    private func content(_ athlete: Athlete) -> some View {
        // Two columns only when the pane itself is wide: an unfolded iPhone Duo is "regular" but its detail pane is narrow.
        GeometryReader { geo in
            if hSize == .regular && geo.size.width >= 900 { wide(athlete) } else { narrow(athlete) }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCheck) { CheckView(athleteID: athleteID, kind: .sideline) }
        .sheet(isPresented: $showReport) { ReportView(athleteID: athleteID) }
    }

    /// Biomarkers by day, or the baseline itself when there's no check yet.
    private func readings(_ athlete: Athlete) -> [DayReading] {
        if !athlete.history.isEmpty { return athlete.history }
        return athlete.hasBaseline ? [DayReading(day: 1, distance: 0.8)] : []
    }

    private func biomarkerTitle(_ athlete: Athlete) -> String {
        athlete.history.isEmpty ? "Baseline biomarkers · \(athlete.baselineDate ?? "")" : "\(athlete.firstName)'s biomarkers"
    }

    /// iPad: who and what to do on the left, the measurements on the right.
    private func wide(_ athlete: Athlete) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: Space.section) {
                    header(athlete)
                    statusPanel(athlete)
                    actions(athlete)
                    EventTimeline(events: athlete.events)
                }
                .frame(width: 380)
                VStack(alignment: .leading, spacing: Space.section) {
                    let r = readings(athlete)
                    if r.isEmpty {
                        ContentUnavailableView("No biomarkers yet", systemImage: Icon.baseline,
                                               description: Text("\(athlete.firstName) hasn't recorded a baseline. A sideline check still runs against the catalog thresholds."))
                            .panel()
                    } else {
                        RecoveryChart(history: r, specs: athlete.biomarkers, title: biomarkerTitle(athlete))
                    }
                    Text("Sideline records measurements and the provider's decision. Return to play requires clearance from a healthcare provider qualified under your state's law.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
        }
    }

    private func narrow(_ athlete: Athlete) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header(athlete)
                statusPanel(athlete)
                if !athlete.history.isEmpty { RecoveryChart(history: athlete.history, specs: athlete.biomarkers, title: biomarkerTitle(athlete)) }
                actions(athlete)
                EventTimeline(events: athlete.events)
                Text("Sideline records measurements and the provider's decision. Return to play requires clearance from a healthcare provider qualified under your state's law.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 20)
        }
    }

    // MARK: Sections

    private func header(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                PlayerPhoto(athlete: athlete, size: 64)
                Text(athlete.name)
                    .font(Typeface.display(34))
                    .foregroundStyle(Palette.ink)
            }
            Text(athlete.sport).font(Typeface.body).foregroundStyle(Palette.muted)
            testRow(athlete)
            HashRule()
        }
    }

    private func testRow(_ athlete: Athlete) -> some View {
        let due = athlete.testDue
        return HStack(spacing: 10) {
            IconLabel(symbol: Icon.time, text: athlete.lastTestLine)
            Spacer()
            Text(due.short)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(due.isOverdue ? Palette.flag : due.needsTest ? Palette.steady : Palette.muted)
        }
        .padding(.top, 4)
    }

    private func statusPanel(_ athlete: Athlete) -> some View {
        let copy = statusCopy(athlete)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(copy.eyebrow, color: copy.tint)
            Text(copy.title).font(Typeface.display(24)).foregroundStyle(Palette.ink)
            Text(copy.body).font(Typeface.body).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .overlay(alignment: .leading) { Rectangle().fill(copy.tint).frame(width: 4) }
    }

    @ViewBuilder
    private func actions(_ athlete: Athlete) -> some View {
        switch athlete.status {
        case .baselineSet:
            VStack(alignment: .leading, spacing: 10) {
                if !athlete.hasBaseline {
                    Text("No baseline yet. The check still runs on the graph's thresholds; there's just no before-and-after.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
                Button("Run sideline check") { showCheck = true }.buttonStyle(SolidButton())
            }
        case .flagged:
            VStack(spacing: 10) {
                Button("Send to provider") { store.requestEvaluation(athlete.id) }
                    .buttonStyle(SolidButton(tint: Palette.flag))
                Button("Preview provider report") { showReport = true }.buttonStyle(OutlineButton())
            }
        case .evaluationRequested, .awaitingProvider:
            Button("View provider report") { showReport = true }.buttonStyle(OutlineButton())
        case .recovering:
            if athlete.isReadyForProviderReview {
                VStack(spacing: 10) {
                    Text("Measurements have stayed inside this athlete's range for three days. A provider decides what happens next.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                    Button("Send report to provider") { store.sendToProvider(athlete.id) }
                        .buttonStyle(SolidButton())
                }
            } else {
                Text("Next recovery check due tomorrow morning.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.muted)
            }
        case .providerSignedOff:
            Button("View record") { showReport = true }.buttonStyle(OutlineButton())
        }
    }

    // MARK: Copy

    private func statusCopy(_ athlete: Athlete) -> (eyebrow: String, title: String, body: String, tint: Color) {
        switch athlete.status {
        case .baselineSet:
            athlete.hasBaseline
                ? ("Baseline", "Baseline on file · \(athlete.baselineDate ?? "")",
                   "One personal baseline, used for every sport and team. Every check is compared with it, not a population average.", Palette.muted)
                : ("Baseline", "No baseline yet",
                   "\(athlete.firstName) records one on their own phone, once. Until then the check uses the catalog thresholds only.", Palette.muted)
        case .flagged:
            ("Flagged", "Removed from play",
             "A healthcare provider's evaluation is the next step. Recovery tracking starts after the provider has seen the athlete.", Palette.flag)
        case .evaluationRequested:
            ("With provider", "Evaluation requested",
             "Waiting on a healthcare provider. The athlete stays out of all activity.", Palette.muted)
        case .recovering(let step):
            ("Recovery", "Step \(step) of 6",
             "Any return of symptoms means stop and re-check. Progress is the provider's call, not the app's.", Palette.ink)
        case .awaitingProvider(let step):
            ("With provider", "Review requested after step \(step)",
             "Waiting on a healthcare provider. Sideline does not clear athletes to play.", Palette.muted)
        case .providerSignedOff(let by):
            ("Provider sign-off", "Sign-off recorded",
             "Entered by \(by). Sideline keeps the provider's record; it does not grant clearance.", Palette.steady)
        }
    }
}
