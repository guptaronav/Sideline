import SwiftUI

/// New-account onboarding: role, account, then team setup (coach) or join + consent (athlete).
/// Demo: finishing signs the person in under the name they typed.
struct RegistrationView: View {
    enum Role: String, CaseIterable, Identifiable {
        case coach, athlete, provider
        var id: String { rawValue }
        var title: String {
            switch self {
            case .coach:    "Coach or instructor"
            case .athlete:  "Athlete"
            case .provider: "Healthcare provider"
            }
        }
        var detail: String {
            switch self {
            case .coach:    "Run sideline checks and manage your team."
            case .athlete:  "Set your normal and follow your comeback plan."
            case .provider: "Review reports and record return-to-play decisions."
            }
        }
        var symbol: String {
            switch self {
            case .coach:    "whistle.fill"
            case .athlete:  "figure.run"
            case .provider: "stethoscope"
            }
        }
    }

    /// Contact and collision sports, each with its iOS athlete silhouette.
    private enum Step: Int { case role, account, team, invite, join, details, consent }

    @Environment(Session.self) private var session
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .role
    @State private var role: Role = .coach
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var organization = "Empower MMA"
    @State private var teamName = "Youth team"
    @State private var sport: Sport = .mma
    @State private var showSportPicker = false
    @State private var ageGroup = "Ages 11–14"
    @State private var teamCode = ""
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -13, to: .now) ?? .now
    @State private var parentName = ""
    @State private var parentEmail = ""
    @State private var consentSent = false
    @State private var consentReceived = false

    private var isMinor: Bool {
        (Calendar.current.dateComponents([.year], from: birthday, to: .now).year ?? 0) < 18
    }

    private var flow: [Step] {
        switch role {
        case .coach:    [.role, .account, .team, .invite]
        case .athlete:  isMinor ? [.role, .account, .join, .details, .consent] : [.role, .account, .join, .details]
        case .provider: [.role, .account]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                progress
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        content
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .role { Button("Cancel") { dismiss() } }
                    else { Button { back() } label: { Image(systemName: "chevron.left") } }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .role:
            header("Who's joining?", "Pick the one that fits you best. You can be added to more teams later.")
            VStack(spacing: 12) {
                ForEach(Role.allCases) { r in
                    Button { role = r } label: { choice(r.symbol, r.title, r.detail, selected: role == r) }
                        .buttonStyle(.plain)
                }
            }
        case .account:
            header("Create your account", role == .athlete ? "Use your own email. Your coach never sees your password." : "You'll use this to sign in.")
            field("person", "Full name", text: $name)
            field("envelope", "Email", text: $email, keyboard: .emailAddress)
            secureField
            Text("At least 8 characters.").font(Typeface.caption).foregroundStyle(Palette.muted)
        case .team:
            header("Create your team", "Athletes join with a code you'll get on the next screen.")
            field("building.2", "Club or school", text: $organization)
            field("person.3", "Team name", text: $teamName)
            Eyebrow("Sport")
            Button { showSportPicker = true } label: {
                HStack(spacing: 12) {
                    SportTile(sport: sport, selected: true).frame(width: 120)
                    Text("Change sport").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.steady)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSportPicker) {
                SportsPicker(title: "Team sport", multiple: false,
                             selection: Binding(get: { [sport] }, set: { if let s = $0.first { sport = s } }))
            }
            Eyebrow("Age group")
            Picker("Age group", selection: $ageGroup) {
                ForEach(["Under 13", "Ages 11–14", "Ages 15–17", "18 and over"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            if ageGroup != "18 and over" {
                note("person.badge.shield.checkmark", "Athletes under 18 need a parent or guardian's consent before their first check. Sideline asks for it when they join.")
            }
        case .invite:
            header("Invite your athletes", "Share this code. Athletes enter it when they sign up.")
            VStack(spacing: 10) {
                Text(inviteCode).font(.system(size: 44, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(Palette.ink)
                Text("\(organization) · \(teamName)").font(Typeface.body).foregroundStyle(Palette.muted)
                ShareLink(item: "Join \(organization) \(teamName) on Sideline with code \(inviteCode).") {
                    Label("Share code", systemImage: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
            note("figure.run", "Each athlete records a 3-minute baseline on their own phone, once. It carries across every team and sport they play. You'll see who's done on your roster.")
        case .join:
            header("Join your team", "Your coach has a team code. Ask them if you don't have it.")
            field("number", "Team code", text: $teamCode)
            if foundTeam {
                HStack(spacing: 12) {
                    IconTile(symbol: "figure.martial.arts", tint: Team.empower.color, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Empower MMA · Youth team").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Text("Coach Ronav Gupta").font(Typeface.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Image(systemName: Icon.check).foregroundStyle(Palette.steady).font(.system(size: 20))
                }
                .padding(14)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
            }
        case .details:
            header("About you", "Your age decides whether a parent or guardian needs to approve.")
            DatePicker("Date of birth", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                .font(.system(size: 17))
                .padding(14)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
            if isMinor {
                note("person.badge.shield.checkmark", "You're under 18, so a parent or guardian approves your account next.")
            }
        case .consent:
            header("Parent or guardian consent", "We'll email them a link to approve. You can set your normal once they agree.")
            field("person", "Parent or guardian name", text: $parentName)
            field("envelope", "Their email", text: $parentEmail, keyboard: .emailAddress)
            if consentSent {
                HStack(spacing: 10) {
                    Image(systemName: consentReceived ? Icon.check : "clock.fill")
                        .foregroundStyle(consentReceived ? Palette.steady : Palette.muted)
                    Text(consentReceived ? "Approved by \(parentName.isEmpty ? "your parent" : parentName)." : "Request sent. Waiting for approval…")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: Primary action

    private var primaryButton: some View {
        Button(buttonTitle) { next() }
            .buttonStyle(SolidButton(tint: Palette.steady))
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
    }

    private var buttonTitle: String {
        switch step {
        case .invite: "Go to my team"
        case .consent: consentReceived ? "Set my normal" : (consentSent ? "Waiting…" : "Send request")
        case .details where !isMinor: "Finish"
        case .account where role == .provider: "Create account"
        default: "Continue"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .account: !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@") && password.count >= 8
        case .team:    !organization.isEmpty && !teamName.isEmpty
        case .join:    foundTeam
        case .consent: consentReceived || (!consentSent && !parentName.isEmpty && parentEmail.contains("@"))
        default:       true
        }
    }

    private var foundTeam: Bool { teamCode.trimmingCharacters(in: .whitespaces).count >= 4 }
    private var inviteCode: String { String(organization.filter(\.isLetter).prefix(3)).uppercased() + "-4821" }

    private func next() {
        if step == .consent && !consentSent {
            consentSent = true
            // Demo: the parent approves a moment later.
            Task { try? await Task.sleep(for: .seconds(2)); consentReceived = true }
            return
        }
        if let i = flow.firstIndex(of: step), i + 1 < flow.count {
            withAnimation(.easeOut(duration: 0.2)) { step = flow[i + 1] }
        } else {
            finish()
        }
    }

    private func back() {
        if let i = flow.firstIndex(of: step), i > 0 { step = flow[i - 1] }
    }

    private func finish() {
        let display = name.trimmingCharacters(in: .whitespaces)
        switch role {
        case .coach:
            session.account = sport == .basketball ? .hayes : .ronav
        case .athlete:
            let id = store.addAthlete(name: display, squad: .mmaYouth)
            session.account = .priya
            session.athleteOverride = id
        case .provider:
            session.account = .okafor
        }
        session.nameOverride = display.isEmpty ? nil : display
        dismiss()
    }

    // MARK: Pieces

    private var progress: some View {
        let total = flow.count
        let index = (flow.firstIndex(of: step) ?? 0) + 1
        return HStack(spacing: 4) {
            ForEach(1...total, id: \.self) { i in
                Capsule().fill(i <= index ? Palette.steady : Palette.rule).frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.ink)
            Text(subtitle).font(Typeface.body).foregroundStyle(Palette.muted)
        }
    }

    private func choice(_ symbol: String, _ title: String, _ detail: String, selected: Bool) -> some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol, tint: selected ? Palette.steady : Palette.muted, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(Typeface.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? Palette.steady : Palette.rule)
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.steady : .clear, lineWidth: 2))
    }

    private func field(_ icon: String, _ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted).frame(width: 20)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .font(.system(size: 17))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var secureField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted).frame(width: 20)
            SecureField("Password", text: $password).textContentType(.oneTimeCode).font(.system(size: 17))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func note(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.steady)
            Text(text).font(Typeface.caption).foregroundStyle(Palette.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.steady.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
