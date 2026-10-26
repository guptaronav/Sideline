import SwiftUI

/// The athlete's own view: plain language, no controls that move them forward.
struct AthleteDashboardView: View {
    @Environment(Store.self) private var store
    @Environment(Session.self) private var session
    @State private var showCheckIn = false

    var body: some View {
        if let athlete = store.athlete(session.athleteID) {
            content(athlete)
        }
    }

    private func content(_ athlete: Athlete) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                RoleBar(title: "Athlete view")
                header(athlete)
                headline(athlete)
                if athlete.status != .baselineSet { today(athlete) }
                if !athlete.history.isEmpty { RecoveryChart(history: athlete.history) }
                if athlete.showsSteps { StepsLadder(athlete: athlete) }
                EventTimeline(events: athlete.events)
                Text("Only a healthcare provider can decide when you return to play. Tell your coach or parent right away if symptoms get worse.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 20)
        }
        .background(Palette.paper.ignoresSafeArea())
        .sheet(isPresented: $showCheckIn) { SymptomCheckInView(athleteID: athlete.id) }
    }

    private func header(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(store.athletes) { other in
                    Button("#\(other.number) \(other.name)") { session.athleteID = other.id }
                }
            } label: {
                HStack(spacing: 6) {
                    Eyebrow("Viewing as demo athlete")
                    Text("▾").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(athlete.number)")
                    .font(Typeface.mono(44, weight: .bold))
                    .foregroundStyle(Palette.muted)
                Text(athlete.name).font(Typeface.display(34)).foregroundStyle(Palette.ink)
            }
            Text(athlete.sport).font(Typeface.body).foregroundStyle(Palette.muted)
            HashRule()
        }
    }

    private func headline(_ athlete: Athlete) -> some View {
        let copy = message(for: athlete.status)
        return VStack(alignment: .leading, spacing: 8) {
            Text(copy.title).font(Typeface.display(30)).foregroundStyle(Palette.ink)
            Text(copy.body).font(Typeface.body).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .overlay(alignment: .leading) { Rectangle().fill(copy.tint).frame(width: 4) }
    }

    private func today(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Today")
            Text("How are you feeling? It takes under a minute, and your provider can see the answers.")
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
            Button("Log today's symptoms") { showCheckIn = true }
                .buttonStyle(SolidButton())
        }
    }

    private func message(for status: RecoveryStatus) -> (title: String, body: String, tint: Color) {
        switch status {
        case .baselineSet:
            ("You're set up.", "Your baseline is on file. If you take a hit, your coach compares the check with your own normal.", Palette.muted)
        case .flagged:
            ("You've been taken out.", "Your coach removed you from play. Stay out of all activity until a healthcare provider has seen you.", Palette.flag)
        case .evaluationRequested:
            ("Waiting on a provider.", "Your report is with a healthcare provider. You stay out of activity until they say otherwise.", Palette.flag)
        case .recovering(let step):
            ("Step \(step) of 6.", "Do only what your provider has approved for this step. Log your symptoms every day.", Palette.ink)
        case .awaitingProvider:
            ("Under provider review.", "Your readings have stayed inside your normal range. Your provider decides what comes next. Don't move up on your own.", Palette.flag)
        case .providerSignedOff(let by):
            ("Provider sign-off on file.", "\(by) recorded their decision. Follow their directions, and tell your coach if symptoms come back.", Palette.steady)
        }
    }
}
