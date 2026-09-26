import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TestbedView: View {
    @StateObject private var capture = CaptureController()

    var body: some View {
        HSplitView {
            previewPane(title: "Raw camera", image: capture.rawPreview)
            previewPane(title: "Composited output", image: capture.processedPreview)
        }
        .frame(minWidth: 900, minHeight: 500)
        .safeAreaInset(edge: .bottom) {
            controls
        }
        .onAppear { capture.start() }
        .onDisappear { capture.stop() }
    }

    private func previewPane(title: String, image: NSImage?) -> some View {
        VStack {
            Text(title).font(.headline)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let diagnostic = capture.diagnosticMessage {
                Color.black.overlay(
                    Text(diagnostic)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                )
            } else {
                Color.black.overlay(Text("No frame yet").foregroundStyle(.white))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Toggle("Enabled", isOn: $capture.config.isEnabled)

            Picker("Mode", selection: $capture.config.overlayMode) {
                Text("Sticker").tag(OverlayMode.sticker)
                Text("Full frame").tag(OverlayMode.fullFrame)
            }
            .frame(width: 180)

            Button("Choose overlay…") { chooseOverlay() }

            Divider().frame(height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Classifier: \(capture.classifierStateText)")
                    .font(.system(.body, design: .monospaced))
                Text(String(format: "Confidence: %.2f", capture.lastGestureConfidence))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .leading) {
                Stepper("Hold frames: \(capture.config.triggerHoldFrames)", value: $capture.config.triggerHoldFrames, in: 1...60)
                Stepper(String(format: "Cooldown: %.1fs", capture.config.cooldownSec), value: $capture.config.cooldownSec, in: 0.5...10, step: 0.5)
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func chooseOverlay() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        capture.config.overlayImageURL = url
    }
}

#Preview {
    TestbedView()
}
