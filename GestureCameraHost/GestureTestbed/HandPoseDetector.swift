import Vision
import CoreImage

/// A single frame's hand-pose read: which fingers are extended, per hand.
struct HandPoseReading {
    enum Chirality { case left, right }
    let chirality: Chirality
    let middleFingerExtended: Bool
    let otherFingersFolded: Bool
    let confidence: Float
}

/// Wraps VNDetectHumanHandPoseRequest and reduces raw joint landmarks
/// down to the boolean reading the gesture classifier needs. Kept
/// separate from the classifier so Milestone 2 can swap in a different
/// (temporal/action) model behind the same call site without touching
/// this file.
final class HandPoseDetector {
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()

    /// Runs synchronously on the frame; callers should invoke this from
    /// the capture callback's queue, not the main thread.
    func detect(in pixelBuffer: CVPixelBuffer) -> [HandPoseReading] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        guard let observations = request.results else { return [] }
        return observations.compactMap { reading(from: $0) }
    }

    private func reading(from observation: VNHumanHandPoseObservation) -> HandPoseReading? {
        guard let allPoints = try? observation.recognizedPoints(.all) else { return nil }

        func point(_ joint: VNHumanHandPoseObservation.JointName) -> VNRecognizedPoint? {
            allPoints[joint]
        }

        // A finger counts as "extended" when its tip is farther from the
        // wrist than its base (PIP) joint by a clear margin — a simple,
        // fast heuristic that's good enough gated behind several
        // consecutive-frame confirmation in the classifier. Swap for
        // angle-based joint math where tighter precision is required.
        guard
            let wrist = point(.wrist), wrist.confidence > 0.3,
            let middleTip = point(.middleTip), let middlePIP = point(.middlePIP),
            let indexTip = point(.indexTip), let indexPIP = point(.indexPIP),
            let ringTip = point(.ringTip), let ringPIP = point(.ringPIP),
            let littleTip = point(.littleTip), let littlePIP = point(.littlePIP)
        else { return nil }

        func extended(tip: VNRecognizedPoint, pip: VNRecognizedPoint) -> Bool {
            let tipDist = hypot(tip.location.x - wrist.location.x, tip.location.y - wrist.location.y)
            let pipDist = hypot(pip.location.x - wrist.location.x, pip.location.y - wrist.location.y)
            return tipDist > pipDist * 1.25
        }

        let middleExtended = extended(tip: middleTip, pip: middlePIP)
        let othersFolded =
            !extended(tip: indexTip, pip: indexPIP) &&
            !extended(tip: ringTip, pip: ringPIP) &&
            !extended(tip: littleTip, pip: littlePIP)

        let avgConfidence = (middleTip.confidence + middlePIP.confidence + wrist.confidence) / 3

        // VNHumanHandPoseObservation doesn't expose chirality directly in
        // older SDKs — if targeting a macOS version where
        // observation.chirality is available, prefer that over a guess.
        return HandPoseReading(
            chirality: .right,
            middleFingerExtended: middleExtended,
            otherFingersFolded: othersFolded,
            confidence: avgConfidence
        )
    }
}
