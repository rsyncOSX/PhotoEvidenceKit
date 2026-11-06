import CoreGraphics
import Foundation
import PhotoEvidenceContracts

/// Caller schedules this synchronous worker off the UI actor. CGImage.cropping
/// can retain an entire source; artifacts are always redrawn into owned buffers.
public enum CloseUpRasterizer {
    public static func render(_ image: CGImage, request: CloseUpRequest, sourceLabel: String) throws -> CloseUpRender {
        try Task.checkCancellation()
        let rect = CloseUpCropGeometry.pixelBounds(for: request, width: image.width, height: image.height)
        let limit = Int(ceil(max(request.viewportSize.width, request.viewportSize.height) * request.displayScale))
        guard let crop = image.cropping(to: rect),
              let artifact = boundedArtifact(crop, maxPixelSize: limit),
              let overview = boundedArtifact(image, maxPixelSize: limit)
        else { throw CloseUpRenderError.unavailable }
        try Task.checkCancellation()
        return CloseUpRender(crop: artifact, overview: overview,
            sourceWidth: image.width, sourceHeight: image.height, sourceLabel: sourceLabel,
            displayedBounds: CloseUpCropGeometry.normalizedBounds(for: request, width: image.width, height: image.height))
    }

    private static func boundedArtifact(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        let factor = min(1, Double(maxPixelSize) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * factor))
        let height = max(1, Int(Double(image.height) * factor))
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
