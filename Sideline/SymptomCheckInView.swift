import SwiftUI

struct SymptomCheckInView: View {
    private static let symptoms = ["Headache", "Dizziness", "Nausea", "Light sensitivity", "Trouble concentrating"]
    private static let levels = ["None", "Mild", "Moderate", "Severe"]

    let athleteID: Int

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scores = Array(repeating: 0, count: SymptomCheckInView.symptoms.count)
    @State private var saved = false

    private var total: Int { scores.reduce(0, +) }
    private var worst: (name: String, score: Int)? {
        guard let top = scores.max(), top > 0, let i = scores.firstIndex(of: top) else { return nil }
        return (Self.symptoms[i], top)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow("Symptom check-in")
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                Text(saved ? "Logged." : "How do you feel right now?")
                    .font(Typeface.display(30))
                    .foregroundStyle(Palette.ink)
                HashRule()
                if saved { outcome } else { form }
            }
            .padding(Space.gutter)
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Self.symptoms.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.symptoms[i]).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                    HStack(spacing: 6) {
                        ForEach(Self.levels.indices, id: \.self) { level in
                            Button { scores[i] = level } label: {
                                Text(Self.levels[level])
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(scores[i] == level ? Palette.paper : Palette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(scores[i] == level ? (level >= 2 ? Palette.flag : Palette.ink) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.rule, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(Self.symptoms[i]): \(Self.levels[level])")
                        }
                    }
                }
            }
            Button("Save check-in", action: save).buttonStyle(SolidButton())
        }
    }

    private var outcome: some View {
        let stop = (worst?.score ?? 0) >= 2
        return VStack(alignment: .leading, spacing: 16) {
            Text(stop
                 ? "Stop all activity today and tell your coach and your provider."
                 : total > 0
                    ? "Mild symptoms still count. Your provider will see them at your next review."
                    : "No symptoms logged today. Your provider still decides your next step.")
                .font(Typeface.body)
                .foregroundStyle(stop ? Palette.flag : Palette.ink)
            Button("Done") { dismiss() }.buttonStyle(OutlineButton())
        }
    }

    private func save() {
        let summary = total == 0
            ? "Symptom check-in: no symptoms."
            : "Symptom check-in: total \(total) of 15 (worst: \(worst?.name ?? "") \(worst?.score ?? 0))."
        store.logSymptoms(athleteID, summary: summary)
        saved = true
    }
}
