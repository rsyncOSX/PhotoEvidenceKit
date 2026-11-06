import Foundation
import CoreGraphics
import PhotoEvidenceContracts

/// Shared by renderers and UI overlays so displayed and sampled bounds agree.
public enum CloseUpCropGeometry {
    public static func pixelBounds(for request: CloseUpRequest, width: Int, height: Int,
                                   sourceToRenderTransform: CloseUpCoordinateTransform = .identity) -> CGRect {
        guard width > 0, height > 0 else { return .zero }
        guard sourceToRenderTransform.isValid else { return .zero }
        let mapped = sourceToRenderTransform.bounds(request.region.bounds)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !mapped.isNull, mapped.width > 0, mapped.height > 0 else { return .zero }
        let selected = CGRect(x: mapped.minX * Double(width), y: mapped.minY * Double(height),
                              width: mapped.width * Double(width), height: mapped.height * Double(height)).integral
        let view = request.viewport.normalized
        let baseWidth = request.mode == .sourcePixels ? min(selected.width, request.viewportSize.width) : selected.width
        let baseHeight = request.mode == .sourcePixels ? min(selected.height, request.viewportSize.height) : selected.height
        let cropWidth = min(Double(width), max(1, floor(baseWidth / view.zoom)))
        let cropHeight = min(Double(height), max(1, floor(baseHeight / view.zoom)))
        let centerX = selected.midX + view.offset.x * selected.width
        let centerY = selected.midY + view.offset.y * selected.height
        return CGRect(x: floor(min(Double(width) - cropWidth, max(0, centerX - cropWidth / 2))),
                      y: floor(min(Double(height) - cropHeight, max(0, centerY - cropHeight / 2))),
                      width: cropWidth, height: cropHeight)
    }

    public static func normalizedBounds(for request: CloseUpRequest, width: Int, height: Int,
                                   sourceToRenderTransform: CloseUpCoordinateTransform = .identity) -> CGRect {
        guard width > 0, height > 0 else { return .zero }
        let rect = pixelBounds(for: request, width: width, height: height, sourceToRenderTransform: sourceToRenderTransform)
        return CGRect(x: rect.minX / Double(width), y: rect.minY / Double(height),
                      width: rect.width / Double(width), height: rect.height / Double(height))
    }

    /// Converts dragging rendered content into a relative inspection offset.
    public static func pannedViewport(_ initial: CloseUpViewport, translation: CGSize,
                                     request: CloseUpRequest, sourceWidth: Int, sourceHeight: Int,
                                     sourceToRenderTransform: CloseUpCoordinateTransform = .identity) -> CloseUpViewport {
        let mapped = sourceToRenderTransform.bounds(request.region.bounds)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !mapped.isNull else { return initial.normalized }
        let selected = CGRect(x: mapped.minX * Double(sourceWidth), y: mapped.minY * Double(sourceHeight),
                              width: mapped.width * Double(sourceWidth), height: mapped.height * Double(sourceHeight)).integral
        guard selected.width > 0, selected.height > 0 else { return initial.normalized }
        let rect = pixelBounds(for: request, width: sourceWidth, height: sourceHeight, sourceToRenderTransform: sourceToRenderTransform)
        guard rect.width > 0, rect.height > 0 else { return initial.normalized }
        let fitScale = min(request.viewportSize.width / rect.width, request.viewportSize.height / rect.height)
        let xFactor = request.mode == .sourcePixels ? 1 / initial.normalized.zoom : 1 / fitScale
        let yFactor = xFactor
        return CloseUpViewport(offset: CGPoint(
            x: initial.offset.x - translation.width * xFactor / selected.width,
            y: initial.offset.y - translation.height * yFactor / selected.height), zoom: initial.zoom).normalized
    }
}
