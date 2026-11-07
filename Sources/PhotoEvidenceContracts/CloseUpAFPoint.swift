import Foundation
import CoreGraphics

/// A recorded camera AF location supplied by the host, not a sharpness claim.
/// Coordinates use the canonical oriented image: top-left origin, x right, y down.
/// The host resolves multiple points and orientation before constructing a target.
public struct CloseUpAFPoint: Equatable, Sendable {
    public let frame: CloseUpFrame
    public let center: CGPoint

    /// Reject invalid metadata rather than silently substituting an image center.
    public init?(frame: CloseUpFrame, center: CGPoint) {
        guard center.x.isFinite, center.y.isFinite,
              (0...1).contains(center.x), (0...1).contains(center.y) else { return nil }
        self.frame = frame
        self.center = center
    }
}

/// Omit a frame from the panel's dictionary to hide AF assistance entirely.
public enum CloseUpAFPointAvailability: Equatable, Sendable {
    case available(CloseUpAFPoint)
    /// Host explanation, for example unsupported metadata or ambiguous active points.
    case unavailable(reason: String)

    public func target(for frame: CloseUpFrame) -> CloseUpAFPoint? {
        guard case .available(let target) = self, target.frame == frame else { return nil }
        return target
    }

    public func explanation(for frame: CloseUpFrame) -> String {
        switch self {
        case .available(let target) where target.frame == frame:
            return "Center this manual region on the recorded AF point. This does not establish sharpness."
        case .available:
            return "AF information belongs to a different source revision. Refresh AF metadata."
        case .unavailable(let reason):
            return reason
        }
    }
}
