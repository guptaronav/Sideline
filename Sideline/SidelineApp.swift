import SwiftUI

@main
struct SidelineApp: App {
    @State private var store = Store()
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(session)
                .tint(Palette.ink)
        }
    }
}

struct RootView: View {
    @Environment(Session.self) private var session

    var body: some View {
        Group {
            switch session.role {
            case .none:      RoleGateView()
            case .athlete:   AthleteDashboardView()
            case .coach:     RosterView()
            case .provider:  ProviderDashboardView()
            }
        }
        .animation(.easeOut(duration: 0.2), value: session.role)
    }
}
