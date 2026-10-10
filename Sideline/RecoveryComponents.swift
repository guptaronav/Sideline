import SwiftUI
import Charts

/// Biomarkers by day: each value against the catalog's reference range and the model's threshold.
struct RecoveryChart: View {
    let history: [DayReading]
    var specs: [BiomarkerSpec] = BiomarkerSpec.tracked
    var title = "Your biomarkers"
    /// Cards per row: 1 on iPhone, 2 on iPad.
    var columns = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(title)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), spacing: 12) {
                ForEach(specs) { spec in
                    BiomarkerCard(spec: spec, history: history)
                }
            }
        }
    }
}

struct BiomarkerCard: View {
    let spec: BiomarkerSpec
    let history: [DayReading]

    var body: some View {
        let today = history.last.map(spec.value) ?? spec.baseline
        let flagged = spec.isFlagged(today)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                IconTile(symbol: spec.test.symbol, tint: spec.test.tint, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(spec.plain).font(Typeface.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(spec.format(today)).font(Typeface.hero(20)).foregroundStyle(flagged ? Palette.flag : Palette.ink)
                    let normal = spec.isAtNormal(today)
                    Text(flagged ? "Past threshold" : normal ? "At your normal" : "Normal \(spec.format(spec.baseline))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(flagged ? Palette.flag : normal ? Palette.steady : Palette.muted)
                }
            }
            Chart {
                if let lo = spec.refLow, let hi = spec.refHigh {
                    RectangleMark(yStart: .value("Low", max(lo, spec.axis.lowerBound)), yEnd: .value("High", min(hi, spec.axis.upperBound)))
                        .foregroundStyle(Palette.steady.opacity(0.10))
                }
                if let t = spec.flagBelow { RuleMark(y: .value("Threshold", t)).foregroundStyle(Palette.flag).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) }
                if let t = spec.flagAbove { RuleMark(y: .value("Threshold", t)).foregroundStyle(Palette.flag).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) }
                RuleMark(y: .value("Baseline", spec.baseline)).foregroundStyle(Palette.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [1, 3]))
                ForEach(history) { r in
                    let v = spec.value(r)
                    LineMark(x: .value("Day", r.day), y: .value(spec.name, v)).foregroundStyle(spec.test.tint)
                    PointMark(x: .value("Day", r.day), y: .value(spec.name, v))
                        .foregroundStyle(spec.isFlagged(v) ? Palette.flag : spec.test.tint)
                        .symbolSize(36)
                }
            }
            .chartYScale(domain: spec.axis)
            .chartXScale(domain: 0.6...(Double(max(history.count, 2)) + 0.4))
            .chartXAxis {
                AxisMarks(values: Array(1...max(history.count, 1))) { v in
                    AxisValueLabel { Text("D\(v.as(Int.self) ?? 0)") }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Palette.rule)
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            .frame(height: 90)
            HStack(spacing: 12) {
                Text(spec.thresholdText)
                Text("Baseline \(spec.format(spec.baseline))")
                Spacer()
                Text(spec.code).font(.system(size: 10, design: .monospaced))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct StepsLadder: View {
    let athlete: Athlete

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Return-to-sport steps").padding(.bottom, 4)
            Text("Each step lasts at least 24 hours. A daily check at your normal moves you up a step.")
                .font(Typeface.caption)
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 12)
            ForEach(ReturnStep.allCases) { step in
                row(step, state: athlete.state(of: step))
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }

    private func row(_ step: ReturnStep, state: StepState) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(state == .upcoming ? Palette.rule : Palette.ink, lineWidth: 1.5)
                if state == .done { Circle().fill(Palette.steady).padding(4) }
                if state == .current { Circle().fill(Palette.ink).padding(7) }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 16, weight: state == .current ? .semibold : .regular))
                    .foregroundStyle(state == .upcoming ? Palette.muted : Palette.ink)
                if step.rawValue >= 5 && state != .done {
                    Text("A clinician signs before this step")
                        .font(Typeface.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            Spacer()
            Text("\(step.rawValue)").font(Typeface.mono(13)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct EventTimeline: View {
    let events: [LogEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Activity log").padding(.bottom, 8)
            ForEach(events.reversed()) { event in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(event.when)
                        .font(Typeface.mono(12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 84, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(event.actor.label, color: color(event.actor))
                        Text(event.text).font(.system(size: 15)).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
    }

    private func color(_ actor: Actor) -> Color {
        switch actor {
        case .provider: Palette.steady
        case .coach:    Palette.ink
        default:        Palette.muted
        }
    }
}

/// Signed-in account: photo, name and role. Tapping it opens the account screen (profile, settings, sign out).
/// Neutral colors: this is identity, not an alert.
struct RoleBar: View {
    let title: String
    @Environment(Session.self) private var session
    @State private var showProfile = false

    var body: some View {
        Button { showProfile = true } label: {
            HStack(spacing: 10) {
                MyPhoto(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.nameOverride ?? session.account?.name ?? title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(session.account?.subtitle ?? "").font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account and settings")
        .sheet(isPresented: $showProfile) { ProfileView() }
    }
}
