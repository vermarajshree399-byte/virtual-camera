import AVFoundation
import CoreImage
import SwiftUI
import Combine

/// Owns the capture session and runs every frame through the same
/// detect → classify → composite pipeline the real extension will use,
/// but instead of pushing frames to a virtual camera device, it publishes
/// two NSImages (raw and composited) plus the classifier's state string
/// so a plain SwiftUI window can show what's happening — exactly enough
/// to validate the gesture logic and tune timing/thresholds before any
/// system-extension work happens.
final class CaptureController: NSObject, ObservableObject {
    @Published var rawPreview: NSImage?
    @Published var processedPreview: NSImage?
    @Published var classifierStateText: String = "idle"
    @Published var lastGestureConfidence: Double = 0
    @Published var diagnosticMessage: String?

    var config = LocalConfig()

    private let session = AVCaptureSession()
    private let outputQueue = DispatchQueue(label: "testbed.videoqueue")
    private let ciContext = CIContext()

    private let handPoseDetector = HandPoseDetector()
    private lazy var classifier = GestureClassifier(config: config)
    private let compositor = FrameCompositor()

    // Throttle UI updates — Vision + compositing runs on every frame,
    // but repainting two full-res NSImages 30x/sec is unnecessary for a
    // debug window and will make the UI feel laggy.
    private var lastUIUpdate = Date.distantPast
    private let uiUpdateInterval: TimeInterval = 1.0 / 15.0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSession()

        case .notDetermined:
            // Explicitly triggers the system permission prompt. Relying
            // on it firing implicitly when the session starts is not
            // reliable across all build/signing configurations — call
            // this directly so failure to prompt is distinguishable
            // from failure to configure.
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStartSession()
                    } else {
                        self?.diagnosticMessage = "Camera access was denied at the prompt."
                    }
                }
            }

        case .denied:
            diagnosticMessage = "Camera access is denied for this app. Check System Settings → Privacy & Security → Camera, or reset with: tccutil reset Camera <bundle-id>"

        case .restricted:
            diagnosticMessage = "Camera access is restricted on this system (e.g. by MDM/parental controls)."

        @unknown default:
            diagnosticMessage = "Unknown camera authorization state."
        }
    }

    private func configureAndStartSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            diagnosticMessage = "No camera device found (AVCaptureDevice.default(for: .video) returned nil)."
            return
        }

        session.beginConfiguration()

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                diagnosticMessage = "Session refused to add camera input."
            }
        } catch {
            // Previously swallowed via `try?` — surfacing it is what
            // actually reveals *why* no frame ever showed up (e.g. a
            // missing NSCameraUsageDescription key throws here with a
            // message naming the missing key, rather than failing
            // silently or prompting).
            diagnosticMessage = "Failed to create camera input: \(error.localizedDescription)"
            session.commitConfiguration()
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        outputQueue.async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
    }
}

extension CaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Render the raw frame BEFORE compositing so the "before" preview
        // reflects the untouched feed even though we mutate in place below.
        let rawImage = makeNSImage(from: pixelBuffer)

        var gestureConfidence: Double = 0
        var didComposite = false

        if config.isEnabled {
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            let readings = handPoseDetector.detect(in: pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            let bestReading = readings.max(by: { $0.confidence < $1.confidence })
            gestureConfidence = Double(bestReading?.confidence ?? 0)
            let gestureDetected = bestReading.map { $0.middleFingerExtended && $0.otherFingersFolded && $0.confidence > 0.5 } ?? false

            let shouldOverlay = classifier.update(gestureDetectedThisFrame: gestureDetected)

            if shouldOverlay, let overlayURL = config.overlayImageURL {
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                didComposite = compositor.composite(overlayURL: overlayURL, mode: config.overlayMode, into: pixelBuffer)
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            }
        }

        let processedImage = didComposite ? makeNSImage(from: pixelBuffer) : rawImage
        let stateText = classifier.debugDescription

        let now = Date()
        guard now.timeIntervalSince(lastUIUpdate) >= uiUpdateInterval else { return }
        lastUIUpdate = now

        DispatchQueue.main.async { [weak self] in
            self?.rawPreview = rawImage
            self?.processedPreview = processedImage
            self?.classifierStateText = stateText
            self?.lastGestureConfidence = gestureConfidence
        }
    }

    private func makeNSImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
