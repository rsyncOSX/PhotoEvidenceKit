import CoreGraphics
import Foundation
import PhotoEvidenceContracts

/// Bounded, independently owned rendering artifacts, not domain measurements.
public struct CloseUpRender: Sendable {
    public let crop: CGImage
    public let overview: CGImage
    public let sourceWidth: Int
    public let sourceHeight: Int
    public let sourceLabel: String
    public let displayedBounds: CGRect

    public init(crop: CGImage, overview: CGImage, sourceWidth: Int, sourceHeight: Int,
                sourceLabel: String, displayedBounds: CGRect) {
        self.crop = crop
        self.overview = overview
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.sourceLabel = sourceLabel
        self.displayedBounds = displayedBounds
    }
}

public protocol CloseUpRendering: Sendable {
    func render(_ request: CloseUpRequest) async throws -> CloseUpRender
}

public enum CloseUpRenderError: Error, LocalizedError {
    case unavailable, sourceChanged
    public var errorDescription: String? {
        switch self {
        case .unavailable: "The inspection image is unavailable. Retry or choose another image."
        case .sourceChanged: "The source changed. Refresh the selection to inspect the updated image."
        }
    }
}
