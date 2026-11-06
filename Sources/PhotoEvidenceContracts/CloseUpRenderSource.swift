import Foundation
import CoreGraphics

/// Render identity is independent of file identity and saved manual regions.
/// Hosts choose stable backend IDs and revise the settings token whenever pixels
/// can change (development, bit depth, crop, straightening, color pipeline, etc.).
public struct CloseUpRenderSource: Equatable, Hashable, Sendable {
    public enum Kind: String, Sendable { case unspecified, original, embeddedPreview, developedRAW }
    public let kind: Kind
    public let backendID: String
    public let revision: String

    public init(kind: Kind, backendID: String, revision: String) {
        self.kind = kind
        self.backendID = backendID
        self.revision = revision
    }

    /// Compatibility default for hosts with one fixed rendering pipeline.
    public static let unspecified = Self(kind: .unspecified, backendID: "unspecified", revision: "1")
}

/// Affine mapping from canonical oriented-image normalized coordinates to the
/// normalized coordinates of the actual developed render. No decoder dependency.
public struct CloseUpCoordinateTransform: Equatable, Sendable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public let tx: Double
    public let ty: Double

    public init(a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1,
                tx: Double = 0, ty: Double = 0) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }

    public static let identity = Self()
    public var isValid: Bool {
        [a, b, c, d, tx, ty].allSatisfy(\.isFinite) && abs(a * d - b * c) > 0.000000001
    }
    private var affine: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
    public func point(_ value: CGPoint) -> CGPoint { value.applying(affine) }
    public func bounds(_ value: CGRect) -> CGRect { value.applying(affine) }
    public func inversePoint(_ value: CGPoint) -> CGPoint? {
        guard isValid else { return nil }
        return value.applying(affine.inverted())
    }
}
