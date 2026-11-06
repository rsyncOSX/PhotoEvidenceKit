import Foundation
import CoreGraphics
import Testing
import PhotoEvidenceContracts
import PhotoEvidenceEngine

@Suite("Crop geometry and raster output")
struct CropGeometryTests {
    let frame = CloseUpFrame(id: URL(filePath: "/fixture/a.jpg"), name: "a", revision: "1")

    @Test(arguments: [CloseUpScaleMode.fitRegion, .sourcePixels], [0.25, 1, 8])
    func boundsStayInsideSource(mode: CloseUpScaleMode, zoom: Double) {
        let request = CloseUpRequest(frame: frame, region: CloseUpRegion(center: .zero),
            mode: mode, displayScale: 2, viewport: CloseUpViewport(offset: CGPoint(x: -4, y: 4), zoom: zoom))
        let rect = CloseUpCropGeometry.pixelBounds(for: request, width: 1200, height: 800)
        #expect(CGRect(x: 0, y: 0, width: 1200, height: 800).contains(rect))
        #expect(rect.width > 0 && rect.height > 0)
    }

    @Test func linkedOffsetsAreLocalToEachRegion() {
        let view = CloseUpViewport(offset: CGPoint(x: 0.1, y: 0), zoom: 2)
        let a = CloseUpRequest(frame: frame, region: CloseUpRegion(center: CGPoint(x: 0.2, y: 0.5)),
            mode: .fitRegion, displayScale: 2, viewport: view)
        let b = CloseUpRequest(frame: frame, region: CloseUpRegion(center: CGPoint(x: 0.7, y: 0.5)),
            mode: .fitRegion, displayScale: 2, viewport: view)
        let ra = CloseUpCropGeometry.pixelBounds(for: a, width: 2000, height: 1000)
        let rb = CloseUpCropGeometry.pixelBounds(for: b, width: 2000, height: 1000)
        #expect(rb.midX - ra.midX == 1000)
        #expect(ra.width == rb.width)
    }

    @Test func sourcePixelZoomHasExplicitPhysicalMeaning() {
        let request = CloseUpRequest(frame: frame, region: CloseUpRegion(fraction: 1),
            mode: .sourcePixels, displayScale: 2, viewport: CloseUpViewport(zoom: 2))
        let rect = CloseUpCropGeometry.pixelBounds(for: request, width: 1200, height: 800)
        #expect(rect.size == CGSize(width: 140, height: 105))
    }

    @Test func fitPanningUsesPortraitLetterboxScale() {
        let request = CloseUpRequest(frame: frame, region: CloseUpRegion(fraction: 0.5),
            mode: .fitRegion, displayScale: 2)
        let moved = CloseUpCropGeometry.pannedViewport(CloseUpViewport(),
            translation: CGSize(width: 28, height: 0), request: request,
            sourceWidth: 1200, sourceHeight: 1800)
        #expect(abs(moved.offset.x + 0.2) < 0.000001)
        #expect(moved.offset.y == 0)
    }

    @Test func artifactBoundsAndOverviewGeometryAgree() throws {
        let context = try #require(CGContext(data: nil, width: 1800, height: 1200, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let source = try #require(context.makeImage())
        let request = CloseUpRequest(frame: frame, region: CloseUpRegion(fraction: 0.8),
            mode: .fitRegion, displayScale: 2, viewport: CloseUpViewport(zoom: 0.5))
        let result = try CloseUpRasterizer.render(source, request: request, sourceLabel: "Fixture")
        #expect(max(result.crop.width, result.crop.height) <= 560)
        #expect(max(result.overview.width, result.overview.height) <= 560)
        #expect(result.displayedBounds == CloseUpCropGeometry.normalizedBounds(for: request, width: 1800, height: 1200))
    }
}
