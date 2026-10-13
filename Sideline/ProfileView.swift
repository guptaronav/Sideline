import SwiftUI
import PhotosUI

/// The signed-in person's own photo, or the placeholder until they add one.
struct MyPhoto: View {
    var size: CGFloat = 34
    @Environment(Session.self) private var session

    var body: some View {
        // A photo added on this device wins; otherwise the profile photo on file, looked up by first name.
        if let image = session.photo.flatMap(UIImage.init(data:))
            ?? session.account.flatMap({ UIImage(named: photoName($0.name)) }) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityLabel("Your photo")
        } else {
            PhotoPlaceholder(size: size)
        }
    }
}

/// Account and settings for every role: photo, name, notifications, privacy, support, sign out.
struct ProfileView: View {
    @Environment(Session.self) private var session
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var legal: LegalDoc?
    @State private var confirmSignOut = false
    @State private var showSports = false

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            List {
                header
                Section("Profile") {
                    LabeledContent("Name") {
                        TextField("Name", text: nameBinding)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Email", value: session.account?.email ?? "")
                    LabeledContent("Role", value: roleText)
                    LabeledContent(session.role == .provider ? "Practice" : "Team", value: teamText)
                    if session.role == .athlete {
                        LabeledContent("Baseline", value: store.athlete(session.athleteID)?.baselineDate.map { "Recorded \($0)" } ?? "Not recorded yet")
                    }
                }
                if session.role == .athlete {
                    sportsSection
                    Section {
                        NavigationLink { AppleHealthView() } label: {
                            HStack(spacing: 12) {
                                HealthMark(size: 28)
                                Text("Apple Health").foregroundStyle(Palette.ink)
                                Spacer()
                                Text(session.health == nil ? "Off" : "Connected").foregroundStyle(Palette.muted)
                            }
                        }
                    } footer: {
                        Text("Send your checks to Health and read sleep, heart rate and workouts.")
                    }
                }
                Section {
                    ForEach(notifications, id: \.key) { item in
                        Toggle(isOn: toggle(item.key)) {
                            row(item.symbol, item.tint, item.title)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(notificationFooter)
                }
                Section("Privacy and security") {
                    Toggle(isOn: toggle("faceID")) { row("faceid", Palette.ink, "Require Face ID") }
                    LabeledContent { Text("Allowed") } label: { row("camera.fill", Palette.steady, "Camera access") }
                    Button { legal = .privacy } label: { link("hand.raised.fill", Palette.steady, "Privacy Policy") }
                }
                Section("Support") {
                    Button {} label: { link("questionmark.circle.fill", Palette.steady, "Help center") }
                    Button {} label: { link("envelope.fill", Palette.steady, "Contact support") }
                    Button { legal = .terms } label: { link("doc.text.fill", Palette.muted, "Terms of Service") }
                }
                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Sideline 1.0 (24)")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .tint(Palette.steady)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $legal) { LegalView(doc: $0) }
            // Presented from the screen, not from inside the list: a sheet inside a List row dismisses this one.
            .sheet(isPresented: $showSports) {
                SportsPicker(title: "Sports I play", multiple: true, selection: Binding(
                    get: { store.athlete(session.athleteID)?.sports ?? [] },
                    set: { if !$0.isEmpty { store.setSports(session.athleteID, $0) } }
                ))
            }
            .confirmationDialog("Sign out of Sideline?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    session.account = nil
                }
            }
            .onChange(of: pickedPhoto) { _, item in
                Task {
                    guard let item else { return }
                    if let data = try? await item.loadTransferable(type: Data.self) { session.photo = data }
                }
            }
        }
    }

    // MARK: Header: photo with change and remove

    private var header: some View {
        Section {
            VStack(spacing: 10) {
                MyPhoto(size: 96)
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Text(session.photo == nil ? "Add photo" : "Change photo").font(.system(size: 15, weight: .semibold))
                }
                if session.photo != nil {
                    Button("Remove photo", role: .destructive) { session.photo = nil; pickedPhoto = nil }
                        .font(.system(size: 14))
                }
                VStack(spacing: 2) {
                    Text(displayName).font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(session.account?.subtitle ?? "").font(Typeface.caption).foregroundStyle(Palette.muted)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .buttonStyle(.borderless)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: Sports

    private var sportsSection: some View {
        let id = session.athleteID
        let chosen = store.athlete(id)?.sports ?? []
        return Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Sport.allCases.filter(chosen.contains)) { SportTile(sport: $0, selected: true) }
            }
            .padding(.vertical, 6)
            Button { showSports = true } label: {
                link("plus", Palette.steady, "Add or change sports")
            }
        } header: {
            Text("Sports I play")
        } footer: {
            Text("Pick every sport you play. Your coaches see them on your profile.")
        }
    }

    // MARK: Pieces

    private func row(_ symbol: String, _ tint: Color, _ title: String) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: tint, size: 28)
            Text(title).foregroundStyle(Palette.ink)
        }
    }

    private func link(_ symbol: String, _ tint: Color, _ title: String) -> some View {
        HStack {
            row(symbol, tint, title)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
        }
    }

    private func toggle(_ key: String) -> Binding<Bool> {
        Binding(get: { session.settings[key] ?? true }, set: { session.settings[key] = $0 })
    }

    private var nameBinding: Binding<String> {
        Binding(get: { displayName }, set: { session.nameOverride = $0 })
    }

    private var displayName: String { session.nameOverride ?? session.account?.name ?? "" }

    private var roleText: String {
        switch session.role {
        case .coach:    "Coach"
        case .athlete:  "Athlete"
        case .provider: "Healthcare provider"
        case nil:       ""
        }
    }

    private var teamText: String {
        switch session.role {
        case .coach:
            let squads = session.account?.squads ?? []
            return ([session.team.name] + [squads.map(\.shortName).joined(separator: ", ")]).joined(separator: " · ")
        case .athlete:
            guard let a = store.athlete(session.athleteID) else { return session.team.name }
            return "\(a.team.name) · \(a.squad.shortName)"
        default:
            return "Chesapeake Sports Medicine"
        }
    }

    private struct Notice { let key: String; let symbol: String; let tint: Color; let title: String }

    private var notifications: [Notice] {
        switch session.role {
        case .coach: [
            Notice(key: "removed", symbol: Icon.alert, tint: Palette.flag, title: "Player removed from play"),
            Notice(key: "steps", symbol: Icon.steps, tint: Palette.steady, title: "Recovery step changes"),
            Notice(key: "signoff", symbol: Icon.clinician, tint: Palette.ink, title: "Clinician sign-off"),
        ]
        case .athlete: [
            Notice(key: "daily", symbol: Icon.time, tint: Palette.steady, title: "Daily check reminder"),
            Notice(key: "updates", symbol: Icon.clinician, tint: Palette.ink, title: "Coach and clinician updates"),
        ]
        default: [
            Notice(key: "requests", symbol: Icon.alert, tint: Palette.flag, title: "New evaluation requests"),
            Notice(key: "steps", symbol: Icon.steps, tint: Palette.steady, title: "Recovery step changes"),
        ]
        }
    }

    private var notificationFooter: String {
        switch session.role {
        case .coach:   "Removed-from-play alerts break through Focus so you see them on the sideline."
        case .athlete: "Your reminder comes at 8:00 AM while you are working through return-to-sport steps."
        default:       "Evaluation requests include the athlete's report and biomarker history."
        }
    }
}

/// A sport as a card: its athlete silhouette large and cropped at the corner, like the team hero art.
struct SportTile: View {
    let sport: Sport
    let selected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Text(sport.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selected ? .white : Palette.ink)
                .padding(12)
        }
        .aspectRatio(1.5, contentMode: .fit)
        .background {
            // Silhouette sized from the tile itself, so it reads the same in any grid width.
            GeometryReader { geo in
                Image(systemName: sport.symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(selected ? .white.opacity(0.3) : Palette.ink.opacity(0.16))
                    .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.9)
                    .position(x: geo.size.width * 0.74, y: geo.size.height * 0.6)
            }
        }
        .background(selected ? Palette.brand : Palette.card)
        .overlay(alignment: .bottomLeading) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Every sport, grouped and searchable, as silhouette tiles. Multi-select for players, single for a coach's team.
struct SportsPicker: View {
    let title: String
    let multiple: Bool
    @Binding var selection: Set<Sport>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Sport.Group.allCases, id: \.self) { group in
                        let sports = Sport.allCases.filter { $0.group == group && matches($0) }
                        if !sports.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(group.rawValue)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                    ForEach(sports) { sport in
                                        Button { toggle(sport) } label: {
                                            SportTile(sport: sport, selected: selection.contains(sport))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(sport.rawValue)
                                        .accessibilityAddTraits(selection.contains(sport) ? .isSelected : [])
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Space.gutter)
            }
            .background(Palette.paper)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search sports")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if multiple {
                    ToolbarItem(placement: .principal) {
                        Text("\(selection.count) selected").font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .tint(Palette.steady)
        }
    }

    private func matches(_ sport: Sport) -> Bool {
        query.isEmpty || sport.rawValue.localizedCaseInsensitiveContains(query)
    }

    private func toggle(_ sport: Sport) {
        if !multiple { selection = [sport]; dismiss(); return }
        var next = selection
        if next.contains(sport) { next.remove(sport) } else { next.insert(sport) }
        if !next.isEmpty { selection = next }
    }
}
