import SwiftUI

struct ResultView: View {
    let athleteID: Int
    let onDone: () -> Void

    @Environment(Store.self) private var store
    @State private var guardianNotified = false

    var body: some View {
        if let athlete = store.athlete(athleteID) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    verdict(athlete)
                    measures(athlete)
                    if athlete.status == .flagged { actions } else { Button("Done", action: onDone).buttonStyle(SolidButton()) }
                    Text("Sideline flags possible concussion signs from eye and pupil measurements. It does not diagnose.")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 24)
            }
        }
    }

    private func verdict(_ athlete: Athlete) -> some View {
        let outside = athlete.injuryMetrics.filter(\.isOutsideRange).count
        let input = athlete.sidelineInput
        let removed = athlete.status == .flagged
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow("#\(athlete.number) \(athlete.name) · sideline check", color: removed ? Palette.flag : Palette.steady)
            Text(removed ? "Remove from play." : "Nothing flagged.")
                .font(Typeface.display(44))
                .foregroundStyle(Palette.ink)
            Rectangle().fill(removed ? Palette.flag : Palette.steady).frame(width: 56, height: 4)
            Text(removed ? "Do not return to activity until a healthcare provider has evaluated \(athlete.firstName)."
                         : "No measured sign crossed a threshold. Watch \(athlete.firstName) closely and recheck if anything changes.")
                .font(Typeface.body)
                .foregroundStyle(Palette.ink)
            if ConcussionModel.isEmergency(input) {
                Label("Pupils differ by more than 1 mm. Call emergency services now.", systemImage: Icon.alert)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.flag)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Concussion model \(String(format: "%.2f", ConcussionModel.probability(input))) · \(ConcussionModel.flags(input).count) of 4 areas flagged")
                    .font(Typeface.mono(14, weight: .semibold))
                    .foregroundStyle(removed ? Palette.flag : Palette.steady)
                ForEach(ConcussionModel.flags(input)) { flag in
                    Text("• \(flag.text) (\(flag.test.name))")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.ink)
                }
                Text("\(outside) of \(athlete.injuryMetrics.count) measures outside \(athlete.firstName)'s range. Close-up Eye Photo saved for the clinician.")
                    .font(Typeface.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func measures(_ athlete: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Against own baseline").padding(.bottom, 8)
            ForEach(athlete.injuryMetrics) { metric in
                MetricRow(metric: metric)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(guardianNotified ? "Guardian notified" : "Log removal and notify guardian") {
                guardianNotified = true
            }
            .buttonStyle(SolidButton(tint: guardianNotified ? Palette.steady : Palette.flag))
            .disabled(guardianNotified)
            Button("Done", action: onDone).buttonStyle(OutlineButton())
        }
    }
}

struct MetricRow: View {
    let metric: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                Spacer()
                Text(valueText(metric.today))
                    .font(Typeface.mono(16, weight: .semibold))
                    .foregroundStyle(metric.isOutsideRange ? Palette.flag : Palette.ink)
            }
            RangeTrack(deviation: metric.deviation, outside: metric.isOutsideRange)
            HStack {
                Text("Baseline \(valueText(metric.baseline))")
                Spacer()
                Text(metric.isOutsideRange ? "Outside range" : "Within range")
                    .foregroundStyle(metric.isOutsideRange ? Palette.flag : Palette.steady)
            }
            .font(Typeface.caption)
            .foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 14)
    }

    private func valueText(_ value: Double) -> String {
        let number = metric.formatted(value)
        return metric.unit.isEmpty ? number : "\(number) \(metric.unit)"
    }
}

/// A track centred on the athlete's baseline. The shaded band is their normal range.
private struct RangeTrack: View {
    let deviation: Double
    let outside: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let marker = min(max(0.5 + deviation / 6, 0.02), 0.98) * w
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.rule).frame(height: 2)
                Rectangle().fill(Palette.steady.opacity(0.22))
                    .frame(width: w / 3, height: 14)
                    .offset(x: w / 3)
                Rectangle().fill(outside ? Palette.flag : Palette.ink)
                    .frame(width: 3, height: 18)
                    .offset(x: marker - 1.5)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}
