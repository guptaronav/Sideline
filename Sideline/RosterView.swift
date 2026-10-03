import SwiftUI

struct RosterView: View {
    @Environment(Store.self) private var store

    private var groups: [(group: RosterGroup, athletes: [Athlete])] {
        RosterGroup.allCases.compactMap { group in
            let items = store.athletes.filter { $0.group == group }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var attentionCount: Int {
        store.athletes.filter { $0.group == .attention }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                    ForEach(groups, id: \.group) { entry in
                        section(entry.group, entry.athletes)
                    }
                    Text("Sideline flags possible concussion signs. It does not diagnose, and it cannot clear an athlete to play.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 24)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationDestination(for: Int.self) { AthleteView(athleteID: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoleBar(title: "Coach view")
            Eyebrow("Ridgeline High · Athletics")
            (Text("Sideline").foregroundColor(Palette.ink) + Text(".").foregroundColor(Palette.flag))
                .font(Typeface.display(40))
            HashRule()
            Text(attentionCount == 0
                 ? "No athletes need attention."
                 : "\(attentionCount) \(attentionCount == 1 ? "athlete needs" : "athletes need") attention.")
                .font(Typeface.body)
                .foregroundStyle(Palette.muted)
        }
    }

    private func section(_ group: RosterGroup, _ athletes: [Athlete]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(group.title, color: group == .attention ? Palette.flag : Palette.muted)
                .padding(.bottom, 10)
            ForEach(athletes) { athlete in
                NavigationLink(value: athlete.id) { row(athlete) }
                    .buttonStyle(.plain)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }

    private func row(_ athlete: Athlete) -> some View {
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
}

struct StatusTag: View {
    let status: RecoveryStatus

    var body: some View {
        switch status {
        case .baselineSet:               Tag(text: "Ready", color: Palette.muted)
        case .flagged:                   Tag(text: "Removed", color: Palette.flag, filled: true)
        case .evaluationRequested:       Tag(text: "With provider", color: Palette.flag)
        case .recovering(let step):      Tag(text: "Step \(step) of 6", color: Palette.ink)
        case .awaitingProvider:          Tag(text: "In review", color: Palette.flag)
        case .providerSignedOff:         Tag(text: "Sign-off", color: Palette.steady)
        }
    }
}
