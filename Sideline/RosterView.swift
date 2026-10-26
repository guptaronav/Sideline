import SwiftUI

/// Coach home: pick one of your teams, see its players as a table.
struct RosterView: View {
    @Environment(Store.self) private var store
    @Environment(Session.self) private var session

    private var squads: [Squad] { session.account?.squads ?? [] }
    private var squad: Squad { session.selectedSquad ?? squads.first ?? .mmaYouth }

    /// Players needing attention first, then recovering, then everyone else.
    private var players: [Athlete] {
        store.athletes(in: squad).sorted { ($0.group.rawValue, $0.name) < ($1.group.rawValue, $1.name) }
    }

    private var attentionCount: Int { players.filter { $0.group == .attention }.count }
    private var overdueCount: Int { players.filter { $0.testDue.isOverdue }.count }

    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selected: Int?

    var body: some View {
        if hSize == .regular { splitBody } else { compactBody }
    }

    /// iPad: the team and its roster on the left, the selected player on the right.
    private var splitBody: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section {
                    RoleBar(title: session.account?.name ?? "Coach")
                    hero
                        .listRowInsets(EdgeInsets())
                    if squads.count > 1 {
                        Picker("Team", selection: Binding(get: { squad }, set: { session.selectedSquad = $0; selected = nil })) {
                            ForEach(squads) { Text($0.shortName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                Section("Players") {
                    ForEach(players) { athlete in
                        row(athlete, chevron: false).tag(athlete.id)
                    }
                }
            }
            .navigationTitle(squad.shortName)
            .toolbar(.hidden, for: .navigationBar)
            .navigationSplitViewColumnWidth(min: 380, ideal: 420)
        } detail: {
            if let id = selected {
                NavigationStack { AthleteView(athleteID: id) }.id(id)
            } else {
                ContentUnavailableView("Select a player", systemImage: Icon.team,
                                       description: Text("Players who need attention or have a test due are at the top."))
            }
        }
        .onAppear { if selected == nil { selected = players.first?.id } }
        .onChange(of: squad) { selected = players.first?.id }
    }

    private var compactBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RoleBar(title: session.account?.name ?? "Coach")
                    hero
                    if squads.count > 1 {
                        Picker("Team", selection: Binding(get: { squad }, set: { session.selectedSquad = $0 })) {
                            ForEach(squads) { Text($0.shortName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    table
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

    private var hero: some View {
        TeamHero(team: squad.team) {
            VStack(alignment: .leading, spacing: 6) {
                // "Youth team · ages 11–14": team name as the title, age band on the eyebrow line, so the title never wraps mid-phrase.
                let parts = squad.name.components(separatedBy: " · ")
                Text(([squad.team.name] + parts.dropFirst()).joined(separator: " · ").uppercased())
                    .font(.system(size: 12, weight: .semibold)).opacity(0.8)
                Text(parts[0]).font(Typeface.display(30))
                HStack(spacing: 14) {
                    IconLabel(symbol: Icon.team, text: "\(players.count) players", color: .white.opacity(0.9))
                    if attentionCount > 0 {
                        IconLabel(symbol: Icon.alert, text: "\(attentionCount) need attention", color: .white)
                    }
                    if overdueCount > 0 {
                        IconLabel(symbol: Icon.time, text: "\(overdueCount) test\(overdueCount == 1 ? "" : "s") overdue", color: .white)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Player")
                Spacer()
                Text("Status")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            ForEach(players) { athlete in
                Rectangle().fill(Palette.rule).frame(height: 1)
                NavigationLink(value: athlete.id) { row(athlete) }
                    .buttonStyle(.plain)
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Last test and whether one is due. Overdue is the alert color: it's the coach's cue to chase it.
    private func testLine(_ athlete: Athlete) -> some View {
        let due = athlete.testDue
        let text: String = {
            switch due {
            case .upToDate: return athlete.lastTestLine
            case .doneToday: return athlete.lastTest.map { "Checked \($0.testStamp.replacingOccurrences(of: "Today", with: "today"))" } ?? due.short
            default: return due.short
            }
        }()
        return Text(text)
            .font(.system(size: 13, weight: due.isOverdue ? .semibold : .regular))
            .foregroundStyle(due.isOverdue ? Palette.flag : due.needsTest ? Palette.steady : Palette.muted)
    }

    private func row(_ athlete: Athlete, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            PlayerPhoto(athlete: athlete, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(athlete.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(athlete.position).font(Typeface.caption).foregroundStyle(Palette.muted)
                testLine(athlete)
            }
            Spacer(minLength: 8)
            if athlete.hasBaseline || athlete.status != .baselineSet {
                StatusTag(status: athlete.status)
            } else {
                Tag(text: "No baseline", color: Palette.muted)
            }
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct StatusTag: View {
    let status: RecoveryStatus

    var body: some View {
        switch status {
        case .baselineSet:               Tag(text: "Ready", color: Palette.muted)
        case .flagged:                   Tag(text: "Removed", color: Palette.flag, filled: true)
        case .evaluationRequested:       Tag(text: "With provider", color: Palette.muted)
        case .recovering(let step):      Tag(text: "Step \(step) of 6", color: Palette.steady)
        case .awaitingProvider:          Tag(text: "In review", color: Palette.muted)
        case .providerSignedOff:         Tag(text: "Signed off", color: Palette.ink)
        }
    }
}
