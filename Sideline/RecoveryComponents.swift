import SwiftUI
import Charts

/// Trend of distance from the athlete's own baseline. The shaded band is their normal range.
struct RecoveryChart: View {
    let history: [DayReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Distance from own baseline")
            Chart {
                RectangleMark(
                    xStart: .value("Start", 0.5),
                    xEnd: .value("End", Double(history.count) + 0.5),
                    yStart: .value("Low", 0),
                    yEnd: .value("High", 1)
                )
                .foregroundStyle(Palette.steady.opacity(0.16))

                ForEach(history) { reading in
                    LineMark(x: .value("Day", reading.day), y: .value("Distance", reading.distance))
                        .foregroundStyle(Palette.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Day", reading.day), y: .value("Distance", reading.distance))
                        .foregroundStyle(reading.distance <= 1 ? Palette.steady : Palette.flag)
                        .symbolSize(40)
                }
            }
            .chartYScale(domain: 0...3.2)
            .chartXScale(domain: 0.5...(Double(history.count) + 0.5))
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { _ in
                    AxisGridLine().foregroundStyle(Palette.rule)
                    AxisValueLabel().font(Typeface.mono(11)).foregroundStyle(Palette.muted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel().font(Typeface.mono(11)).foregroundStyle(Palette.muted)
                }
            }
            .frame(height: 190)
            .accessibilityLabel("Recovery trend")
            .accessibilityValue("Latest reading \(String(format: "%.1f", history.last?.distance ?? 0)) from baseline; 1.0 is the edge of the normal range.")
            Text("The shaded band is this athlete's own normal range. Simulated data.")
                .font(Typeface.caption)
                .foregroundStyle(Palette.muted)
        }
    }
}

struct StepsLadder: View {
    let athlete: Athlete

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Return-to-sport steps").padding(.bottom, 4)
            Text("Each step lasts at least 24 hours. Symptoms are re-checked at every step.")
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
                if step.rawValue >= 4 && state != .done {
                    Text("Requires resolved symptoms")
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
                        .frame(width: 64, alignment: .leading)
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
        case .coach:    Palette.flag
        default:        Palette.muted
        }
    }
}

/// Role label with a way back to the role gate.
struct RoleBar: View {
    let title: String
    @Environment(Session.self) private var session

    var body: some View {
        HStack {
            Eyebrow(title, color: Palette.flag)
            Spacer()
            Button("Switch role") { session.role = nil }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
    }
}
