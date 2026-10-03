import SwiftUI

/// One-page summary for a healthcare provider. It reports measurements; it draws no conclusions.
struct ReportView: View {
    let athleteID: Int

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let athlete = store.athlete(athleteID) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        masthead(athlete)
                        if !athlete.injuryMetrics.isEmpty { table(athlete) }
                        if !athlete.history.isEmpty { recovery(athlete) }
                        provider(athlete)
                        Text("Prepared by Sideline from simulated demonstration data. This report contains measurements only. It is not a diagnosis and does not clear an athlete to play.")
                            .font(Typeface.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(Space.gutter)
                }
                .background(Palette.paper.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { ShareLink(item: summary(athlete)) }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func masthead(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Provider report")
            Text("#\(athlete.number) \(athlete.name)").font(Typeface.display(30)).foregroundStyle(Palette.ink)
            Text(athlete.sport).font(Typeface.body).foregroundStyle(Palette.muted)
            HashRule()
        }
    }

    private func table(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Injury-day check vs. own baseline").padding(.bottom, 8)
            ForEach(athlete.injuryMetrics) { m in
                HStack {
                    Text(m.name).font(.system(size: 15))
                    Spacer()
                    Text("\(m.formatted(m.baseline)) → \(m.formatted(m.today))")
                        .font(Typeface.mono(14, weight: .semibold))
                        .foregroundStyle(m.isOutsideRange ? Palette.flag : Palette.ink)
                }
                .padding(.vertical, 10)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }

    private func recovery(_ athlete: Athlete) -> some View {
        let inRange = athlete.history.suffix(3).allSatisfy { $0.distance <= 1.0 }
        return VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Recovery log")
            Text("\(athlete.history.count) daily checks recorded. Last reading \(String(format: "%.1f", athlete.history.last?.distance ?? 0)) from baseline.")
                .font(Typeface.body)
            Text(inRange ? "Last three readings were inside the athlete's own range." : "Readings are not yet consistently inside the athlete's range.")
                .font(Typeface.body)
                .foregroundStyle(Palette.muted)
        }
    }

    private func provider(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Provider decision")
            switch athlete.status {
            case .providerSignedOff(let by):
                let when = athlete.events.last(where: { $0.actor == .provider })?.when.lowercased() ?? "on file"
                Text("Recorded by \(by), \(when).").font(Typeface.body)
            default:
                Text("Pending. A healthcare provider qualified under state law makes the return-to-play decision.")
                    .font(Typeface.body)
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private func summary(_ athlete: Athlete) -> String {
        "Sideline provider report — #\(athlete.number) \(athlete.name), \(athlete.sport). Measurements only; not a diagnosis. Simulated demo data."
    }
}
