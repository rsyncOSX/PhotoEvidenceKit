import Foundation
import CoreGraphics

/// A host-owned source identity and revision. The URL identifies the source;
/// revision must be stable across launches and change when the source changes.
public struct CloseUpFrame: Identifiable, Equatable, Sendable {
    public let id: URL
    public let name: String
    public let revision: String

    public init(id: URL, name: String, revision: String) {
        self.id = id
        self.name = name
        self.revision = revision
    }
}

/// Manual selection in an orientation-corrected image. Origin is top-left;
/// x increases rightward and y downward. This is not a detected subject or eye.
public struct CloseUpRegion: Equatable, Codable, Sendable {
    public var center: CGPoint
    public var fraction: Double

    public init(center: CGPoint = CGPoint(x: 0.5, y: 0.5), fraction: Double = 0.25) {
        self.center = center
        self.fraction = fraction
    }

    public var bounds: CGRect {
        let side = min(1, max(0.05, fraction.isFinite ? fraction : 0.25))
        let x = center.x.isFinite ? center.x : 0.5
        let y = center.y.isFinite ? center.y : 0.5
        return CGRect(x: min(1 - side, max(0, x - side / 2)),
                      y: min(1 - side, max(0, y - side / 2)), width: side, height: side)
    }

    /// Canonical finite representation suitable for persistence and geometry.
    public var normalized: Self {
        let rect = bounds
        return Self(center: CGPoint(x: rect.midX, y: rect.midY), fraction: rect.width)
    }

    public func pixelBounds(width: Int, height: Int) -> CGRect {
        guard width > 0, height > 0 else { return .zero }
        let rect = bounds
        return CGRect(x: rect.minX * Double(width), y: rect.minY * Double(height),
                      width: rect.width * Double(width), height: rect.height * Double(height))
            .integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

public enum CloseUpScaleMode: String, CaseIterable, Sendable {
    case fitRegion, sourcePixels
}

/// Temporary inspection around a frame's own region. Offset is measured in
/// fractions of that region, not full-image coordinates. Zoom is points per
/// source pixel in source-pixel mode; 1 means one pixel per display point.
public struct CloseUpViewport: Equatable, Sendable {
    public var offset: CGPoint
    public var zoom: Double

    public init(offset: CGPoint = .zero, zoom: Double = 1) {
        self.offset = offset
        self.zoom = zoom
    }

    public var normalized: Self {
        Self(offset: CGPoint(x: offset.x.isFinite ? min(4, max(-4, offset.x)) : 0,
                             y: offset.y.isFinite ? min(4, max(-4, offset.y)) : 0),
             zoom: zoom.isFinite ? min(8, max(0.25, zoom)) : 1)
    }
}

/// Complete value request; the renderer must honor the source and scale or fail.
public struct CloseUpRequest: Equatable, Sendable {
    public let frame: CloseUpFrame
    public let region: CloseUpRegion
    public let mode: CloseUpScaleMode
    public let displayScale: Double
    public let viewport: CloseUpViewport
    public let viewportSize: CGSize

    public init(frame: CloseUpFrame, region: CloseUpRegion, mode: CloseUpScaleMode,
                displayScale: Double, viewport: CloseUpViewport = CloseUpViewport(),
                viewportSize: CGSize = CGSize(width: 280, height: 210)) {
        self.frame = frame
        self.region = region
        self.mode = mode
        self.displayScale = displayScale.isFinite ? min(4, max(1, displayScale)) : 1
        self.viewport = viewport.normalized
        self.viewportSize = CGSize(
            width: viewportSize.width.isFinite ? min(4096, max(1, viewportSize.width)) : 280,
            height: viewportSize.height.isFinite ? min(4096, max(1, viewportSize.height)) : 210)
    }
}

/// Versioned, source-bound photographer choice. Derived images are never stored.
public struct CloseUpRegionRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sourceID: URL
    public let sourceRevision: String
    public let region: CloseUpRegion

    public init(frame: CloseUpFrame, region: CloseUpRegion) {
        schemaVersion = 1
        sourceID = frame.id
        sourceRevision = frame.revision
        self.region = region.normalized
    }

    public func region(for frame: CloseUpFrame) -> CloseUpRegion? {
        guard schemaVersion == 1, sourceID == frame.id, sourceRevision == frame.revision else { return nil }
        return region.normalized
    }
}

/// Injected, preference-sized storage. Implementations must be fast on the main
/// actor (e.g. a hydrated repository or UserDefaults). Throw to expose failures;
/// PhotoEvidenceKit retains unsaved choices for retry rather than discarding them.
@MainActor public protocol CloseUpRegionStoring: AnyObject {
    func load(for frame: CloseUpFrame) throws -> CloseUpRegionRecord?
    func save(_ record: CloseUpRegionRecord) throws
}
