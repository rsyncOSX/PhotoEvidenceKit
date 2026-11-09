import CoreGraphics
import PhotoEvidenceContracts

public enum DetectedFaceRasterizer {
    /// Crops the same upright preview used for detection, with context around the face.
    public static func crop(_ face: DetectedFaceCloseUp, from preview: CGImage) -> CGImage? {
        let bounds = face.normalizedBounds
        guard [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy(\.isFinite),
              !bounds.isEmpty else { return nil }
        let width = CGFloat(preview.width)
        let height = CGFloat(preview.height)
        let pixels = CGRect(x: bounds.minX * width, y: bounds.minY * height,
                            width: bounds.width * width, height: bounds.height * height)
        let padded = pixels.insetBy(dx: -pixels.width * 0.2, dy: -pixels.height * 0.2)
        let clipped = padded.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !clipped.isEmpty else { return nil }
        return preview.cropping(to: clipped)
    }
}
