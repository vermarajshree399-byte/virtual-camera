import Foundation

/// Identical state machine to `Shared/GestureClassifier.swift` from the
/// full plan — copied here reading from `LocalConfig` instead of the
/// App-Group-backed `SharedConfig` so the testbed has zero dependency on
/// entitlements. In the real extension, `Shared/GestureClassifier.swift`
/// is used unchanged.
final class GestureClassifier {
    enum State: Equatable {
        case idle
        case confirming(consecutiveFrames: Int)
        case triggered(since: Date)
        case cooldown(since: Date)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.confirming(let a), .confirming(let b)): return a == b
            case (.triggered, .triggered): return true
            case (.cooldown, .cooldown): return true
            default: return false
            }
        }
    }

    private(set) var state: State = .idle
    private let config: LocalConfig

    init(config: LocalConfig) {
        self.config = config
    }

    @discardableResult
    func update(gestureDetectedThisFrame: Bool) -> Bool {
        let now = Date()
        let requiredFrames = config.triggerHoldFrames
        let overlayDuration = config.overlayDurationSec
        let cooldown = config.cooldownSec

        switch state {
        case .idle:
            state = gestureDetectedThisFrame ? .confirming(consecutiveFrames: 1) : .idle

        case .confirming(let count):
            if !gestureDetectedThisFrame {
                state = .idle
            } else if count + 1 >= requiredFrames {
                state = .triggered(since: now)
            } else {
                state = .confirming(consecutiveFrames: count + 1)
            }

        case .triggered(let since):
            if now.timeIntervalSince(since) >= overlayDuration {
                state = .cooldown(since: now)
            }

        case .cooldown(let since):
            if now.timeIntervalSince(since) >= cooldown {
                state = .idle
            }
        }

        if case .triggered = state { return true }
        return false
    }

    func reset() { state = .idle }

    /// Human-readable state, for the on-screen debug log.
    var debugDescription: String {
        switch state {
        case .idle: return "idle"
        case .confirming(let n): return "confirming (\(n) frames)"
        case .triggered: return "TRIGGERED — overlay active"
        case .cooldown: return "cooldown"
        }
    }
}
