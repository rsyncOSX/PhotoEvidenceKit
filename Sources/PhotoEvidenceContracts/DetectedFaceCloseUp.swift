import CoreGraphics

/// A transient detected region in an upright preview. Independent of manual regions.
public struct DetectedFaceCloseUp: Equatable, Identifiable, Sendable {
    public let id: Int
    public let normalizedBounds: CGRect
    public let localDetail: Double?

    public init(id: Int, normalizedBounds: CGRect, localDetail: Double?) {
        self.id = id
        self.normalizedBounds = normalizedBounds
        self.localDetail = localDetail
    }
}
