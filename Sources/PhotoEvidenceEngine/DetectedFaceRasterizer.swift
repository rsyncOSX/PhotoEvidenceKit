import CoreGraphics
import PhotoEvidenceContracts

public enum DetectedFaceRasterizer {
    /// Largest edge of a returned crop; detected-face crops are shown as small tiles.
    public static let defaultMaxPixelSize = 512

    /// Crops the same upright preview used for detection, with context around the face.
    /// The crop is redrawn into an owned buffer: `CGImage.cropping(to:)` alone
    /// shares the preview's backing store and would keep the whole decoded
    /// preview alive for as long as the tile is retained.
    public static func crop(_ face: DetectedFaceCloseUp, from preview: CGImage,
                            maxPixelSize: Int = defaultMaxPixelSize) -> CGImage? {
        let bounds = face.normalizedBounds
        guard [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy(\.isFinite),
              !bounds.isEmpty else { return nil }
        let width = CGFloat(preview.width)
        let height = CGFloat(preview.height)
        let pixels = CGRect(x: bounds.minX * width, y: bounds.minY * height,
                            width: bounds.width * width, height: bounds.height * height)
        let padded = pixels.insetBy(dx: -pixels.width * 0.2, dy: -pixels.height * 0.2)
        let clipped = padded.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !clipped.isEmpty, let shared = preview.cropping(to: clipped) else { return nil }
        return CloseUpRasterizer.boundedArtifact(shared, maxPixelSize: max(1, maxPixelSize))
    }
}
