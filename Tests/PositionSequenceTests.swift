import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
private struct PositionSequenceTests {
    static func main() {
        let sequence = PositionSequence()

        let start = sequence.state(at: 0)
        expect(start.completedChecks == 0, "the positioning sequence starts with every check pending")
        expect(start.meshOpacity == 1, "the AR mesh is fully visible at the start")
        expect(!start.isReady, "the athlete is not ready at the start")

        let twoChecks = sequence.state(at: 1.25)
        expect(twoChecks.completedChecks == 2, "two checks complete after 1.2 seconds")
        expect(twoChecks.meshOpacity == 1, "the mesh remains visible while early checks complete")

        let fading = sequence.state(at: 2.1)
        expect(fading.completedChecks == 3, "the third check completes before the mesh finishes fading")
        expect(fading.meshOpacity > 0 && fading.meshOpacity < 1, "the mesh fades during the final readiness check")

        let ready = sequence.state(at: 2.45)
        expect(ready.completedChecks == PositionSequence.checks.count, "all checks are blue before countdown")
        expect(ready.meshOpacity == 0, "only the clean photo remains once ready")
        expect(ready.isReady, "the countdown begins only after all checks complete")
        expect(ready.countdown == 3, "the clean-photo countdown starts at three")

        let lastSecond = sequence.state(at: 4.6)
        expect(lastSecond.countdown == 1, "the countdown reaches one before the positioning phase ends")
        expect(PositionSequence.length == 5.4, "the full phase includes checks plus a three-second countdown")

        expect(PositionComposition.faceGuideHeightToWidth <= 1.18,
               "the face guide is head-shaped, not a tall profile-photo oval")
        expect(PositionComposition.fallbackMeshRows >= 20,
               "the simulator fallback is dense enough to read as a tracked face mesh")
        expect(PositionComposition.fallbackMeshColumns >= 16,
               "the simulator fallback has enough facial detail across each row")

        print("PASS: PositionSequence")
    }
}
