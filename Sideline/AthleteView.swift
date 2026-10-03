import SwiftUI

struct AthleteView: View {
    let athleteID: Int

    @Environment(Store.self) private var store
    @State private var showCheck = false
    @State private var showReport = false

    var body: some View {
        if let athlete = store.athlete(athleteID) {
            content(athlete)
        }
    }

    private func content(_ athlete: Athlete) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                header(athlete)
                statusPanel(athlete)
                if !athlete.history.isEmpty { RecoveryChart(history: athlete.history) }
                if athlete.showsSteps { StepsLadder(athlete: athlete) }
                actions(athlete)
                EventTimeline(events: athlete.events)
                Text("Sideline records measurements and the provider's decision. Return to play requires clearance from a healthcare provider qualified under your state's law.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 20)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCheck) { CheckView(athleteID: athleteID) }
        .sheet(isPresented: $showReport) { ReportView(athleteID: athleteID) }
    }

    // MARK: Sections

    private func header(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(athlete.number)")
                    .font(Typeface.mono(44, weight: .bold))
                    .foregroundStyle(Palette.muted)
                Text(athlete.name)
                    .font(Typeface.display(34))
                    .foregroundStyle(Palette.ink)
            }
            Text(athlete.sport).font(Typeface.body).foregroundStyle(Palette.muted)
            HashRule()
        }
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
            Button("Run sideline check") { showCheck = true }.buttonStyle(SolidButton())
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
            ("Baseline", "Baseline on file",
             "Every check is compared with this athlete's own readings, not a population average.", Palette.muted)
        case .flagged:
            ("Flagged", "Removed from play",
             "A healthcare provider's evaluation is the next step. Recovery tracking starts after the provider has seen the athlete.", Palette.flag)
        case .evaluationRequested:
            ("With provider", "Evaluation requested",
             "Waiting on a healthcare provider. The athlete stays out of all activity.", Palette.flag)
        case .recovering(let step):
            ("Recovery", "Step \(step) of 6",
             "Any return of symptoms means stop and re-check. Progress is the provider's call, not the app's.", Palette.ink)
        case .awaitingProvider(let step):
            ("With provider", "Review requested after step \(step)",
             "Waiting on a healthcare provider. Sideline does not clear athletes to play.", Palette.flag)
        case .providerSignedOff(let by):
            ("Provider sign-off", "Sign-off recorded",
             "Entered by \(by). Sideline keeps the provider's record; it does not grant clearance.", Palette.steady)
        }
    }
}
