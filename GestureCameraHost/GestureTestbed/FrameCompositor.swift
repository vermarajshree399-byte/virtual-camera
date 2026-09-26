import CoreImage
import CoreVideo

enum OverlayMode {
    case sticker
    case fullFrame
}

/// Same compositing logic as `Shared/FrameCompositor.swift`, but the
/// overlay image is loaded from any file URL the user picks (via
/// NSOpenPanel in the testbed UI) rather than an App Group container —
/// there's no second process to share it with here.
final class FrameCompositor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var cachedOverlay: (url: URL, image: CIImage)?

    private func overlayImage(url: URL) -> CIImage? {
        if let cached = cachedOverlay, cached.url == url {
            return cached.image
        }
        guard let img = CIImage(contentsOf: url) else { return nil }
        cachedOverlay = (url, img)
        return img
    }

    @discardableResult
    func composite(overlayURL: URL, mode: OverlayMode, into pixelBuffer: CVPixelBuffer) -> Bool {
        guard let overlay = overlayImage(url: overlayURL) else { return false }

        let baseImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = baseImage.extent

        let positionedOverlay: CIImage
        switch mode {
        case .fullFrame:
            let scale = min(extent.width / overlay.extent.width, extent.height / overlay.extent.height)
            positionedOverlay = overlay
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(
                    translationX: (extent.width - overlay.extent.width * scale) / 2,
                    y: (extent.height - overlay.extent.height * scale) / 2
                ))
        case .sticker:
            let scale = (extent.width * 0.25) / overlay.extent.width
            let scaled = overlay.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let margin: CGFloat = 24
            positionedOverlay = scaled.transformed(by: CGAffineTransform(
                translationX: extent.width - scaled.extent.width - margin,
                y: margin
            ))
        }

        let composited = positionedOverlay.composited(over: baseImage)
        context.render(composited, to: pixelBuffer)
        return true
    }
}
