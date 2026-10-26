import SwiftUI

struct RoleGateView: View {
    @Environment(Session.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Ridgeline High · Athletics")
                    (Text("Sideline").foregroundColor(Palette.ink) + Text(".").foregroundColor(Palette.flag))
                        .font(Typeface.display(40))
                    HashRule()
                    Text("Who's using Sideline?")
                        .font(Typeface.display(26))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 8)
                }

                VStack(spacing: 0) {
                    ForEach(Role.allCases) { role in
                        Button { session.role = role } label: { row(role) }
                            .buttonStyle(.plain)
                        Rectangle().fill(Palette.rule).frame(height: 1)
                    }
                }

                Text("Demo with simulated data. Changes carry across roles: a coach's report appears in the provider's queue, and a provider's decision shows up for the athlete and coach.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 24)
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    private func row(_ role: Role) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(role.title).font(Typeface.display(26)).foregroundStyle(Palette.ink)
                Text(role.blurb).font(Typeface.body).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Text("→").font(Typeface.mono(20)).foregroundStyle(Palette.flag)
        }
        .padding(.vertical, 20)
        .contentShape(Rectangle())
    }
}
