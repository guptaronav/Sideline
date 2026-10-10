import SwiftUI

/// The athlete's own app. The tests are the daily task; nothing here asks how they feel.
struct AthleteDashboardView: View {
    private struct CheckRequest: Identifiable {
        let id = UUID()
        let kind: CheckKind
    }

    @Environment(Store.self) private var store
    @Environment(Session.self) private var session
    @State private var request: CheckRequest?

    var body: some View {
        if let athlete = store.athlete(session.athleteID) {
            content(athlete)
        }
    }

    private func content(_ athlete: Athlete) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                RoleBar(title: athlete.team.name)
                header(athlete)
                testCard(athlete)
                if let note = note(athlete) { note }
                HealthCard(athlete: athlete)
                if !athlete.history.isEmpty { RecoveryChart(history: athlete.history, specs: athlete.biomarkers) }
                EventTimeline(events: athlete.events)
                Text("Only a healthcare provider can decide when you return to play. Tell your coach or parent right away if you feel worse.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 20)
        }
        .background(Palette.paper.ignoresSafeArea())
        .fullScreenCover(item: $request) { r in CheckView(athleteID: athlete.id, kind: r.kind) }
    }

    private func header(_ athlete: Athlete) -> some View {
        TeamHero(team: athlete.team) {
            HStack(spacing: 16) {
                PlayerPhoto(athlete: athlete, size: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(athlete.name).font(Typeface.display(28))
                    Text(athlete.sport).font(Typeface.body).opacity(0.85)
                    HStack(spacing: 10) {
                        ForEach(Sport.allCases.filter(athlete.sports.contains)) { sport in
                            Label(sport.rawValue, systemImage: sport.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .opacity(0.85)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: Tests: the hero

    /// The one thing the athlete does: take the test. Due, overdue or done, when they last took it, and the button.
    private func testCard(_ athlete: Athlete) -> some View {
        let due = athlete.testDue
        let tint = due.isOverdue ? Palette.flag : due.needsTest ? Palette.steady : Palette.muted
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(due.kind == .baseline ? "Your baseline" : "Your tests", color: tint)
                Spacer()
                statusTag(due)
            }
            Text(headline(due)).font(Typeface.display(28)).foregroundStyle(Palette.ink)
            IconLabel(symbol: Icon.time, text: athlete.lastTestLine)
            switch due {
            case .dueToday, .overdue, .baselineDue, .baselineOverdue:
                Text(explainer(due, athlete)).font(Typeface.body).foregroundStyle(Palette.muted)
                testList(due.kind.tests)
                Button(due.kind == .baseline ? "Set your normal · \(due.kind.minutes) min" : "Start today's check · \(due.kind.minutes) min") {
                    request = CheckRequest(kind: due.kind)
                }
                .buttonStyle(SolidButton(tint: due.isOverdue ? Palette.flag : Palette.steady))
            case .doneToday:
                if let r = athlete.history.last {
                    let atNormal = athlete.biomarkers.filter { $0.isAtNormal($0.value(r)) }.count
                    Text("\(atNormal) of \(athlete.biomarkers.count) biomarkers at your normal.")
                        .font(Typeface.body).foregroundStyle(Palette.ink)
                }
                IconLabel(symbol: Icon.date, text: "Next check due tomorrow")
            case .waitingForProvider:
                Text("You were removed after a sideline check. Your daily checks start once your doctor has seen you.")
                    .font(Typeface.body).foregroundStyle(Palette.muted)
            case .upToDate(let next):
                Text("Your baseline from \(athlete.baselineDate ?? "earlier") covers every sport you play. If you take a hit, the check compares you with it.")
                    .font(Typeface.body).foregroundStyle(Palette.muted)
                if let next { IconLabel(symbol: Icon.date, text: "Next baseline due \(next.formatted(.dateTime.month(.abbreviated).year()))") }
            }
            if let step = athlete.currentStep, let s = ReturnStep(rawValue: step) {
                Rectangle().fill(Palette.rule).frame(height: 1)
                IconLabel(symbol: Icon.steps, text: "Step \(step) of 6 · \(s.title.lowercased()). \(s.today)")
            }
        }
        .panel()
        .overlay(alignment: .leading) { if due.isOverdue { Rectangle().fill(Palette.flag).frame(width: 4) } }
    }

    private func headline(_ due: TestDue) -> String {
        switch due {
        case .doneToday:                "Today's check is done"
        case .dueToday:                 "Daily check due today"
        case .overdue(let d):           "Daily check overdue by \(d) day\(d == 1 ? "" : "s")"
        case .baselineDue:              "Set your normal"
        case .baselineOverdue:          "Your baseline is overdue"
        case .waitingForProvider:       "No test due"
        case .upToDate:                 "You're up to date"
        }
    }

    private func explainer(_ due: TestDue, _ athlete: Athlete) -> String {
        switch due {
        case .overdue:
            "Missed checks hold your comeback. Take it now; your coach and doctor see when checks are missed."
        case .baselineDue, .baselineOverdue:
            "\(CheckKind.baseline.tests.count) short tests, done once. Your coach can't compare you after a hit without it."
        default:
            "Back at your normal moves you up a step."
        }
    }

    private func statusTag(_ due: TestDue) -> some View {
        switch due {
        case .doneToday:                Tag(text: "Done", color: Palette.steady)
        case .dueToday, .baselineDue:   Tag(text: "Due", color: Palette.steady, filled: true)
        case .overdue, .baselineOverdue: Tag(text: "Overdue", color: Palette.flag, filled: true)
        case .waitingForProvider:       Tag(text: "Waiting", color: Palette.muted)
        case .upToDate:                 Tag(text: "Up to date", color: Palette.steady)
        }
    }

    // MARK: Status notes (no test to take)

    private func note(_ athlete: Athlete) -> AnyView? {
        switch athlete.status {
        case .awaitingProvider:
            AnyView(note("With your doctor", "Two checks in a row at your normal.",
                         "Your doctor has your report and decides what comes next. Keep taking your daily check.", Palette.steady))
        case .providerSignedOff(let by):
            AnyView(note("Signed off", "Back to full play.", "\(by) signed off on your return. Tell your coach if anything feels off.", Palette.steady))
        default:
            nil
        }
    }

    private func note(_ eyebrow: String, _ title: String, _ body: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(eyebrow, color: tint)
            Text(title).font(Typeface.display(28)).foregroundStyle(Palette.ink)
            Text(body).font(Typeface.body).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 4) }
    }

    private func testList(_ tests: [GraphTest]) -> some View {
        VStack(spacing: 0) {
            ForEach(tests) { test in
                HStack(alignment: .center, spacing: 12) {
                    IconTile(symbol: test.symbol, tint: test.tint, size: 32)
                    Text(test.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    IconLabel(symbol: Icon.time, text: "\(test.seconds) s")
                }
                .padding(.vertical, 9)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }
}
