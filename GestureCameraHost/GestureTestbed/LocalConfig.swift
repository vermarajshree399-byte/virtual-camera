import Foundation
import Combine

/// Single-process stand-in for `SharedConfig`. No App Group, no
/// cross-process sharing — this app is the only process reading and
/// writing it, so plain `UserDefaults.standard` (or even just an
/// `ObservableObject`, as here) is enough. In the real extension, the
/// host app and extension go back to `SharedConfig`/App Groups from
/// the original plan; this file is only for the testbed.
final class LocalConfig: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var overlayMode: OverlayMode = .sticker
    @Published var overlayImageURL: URL?
    @Published var triggerHoldFrames: Int = 10   // ~300-500ms at typical sampling cadence
    @Published var overlayDurationSec: Double = 2.0
    @Published var cooldownSec: Double = 2.0
}
