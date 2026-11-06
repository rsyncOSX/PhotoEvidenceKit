import CoreGraphics
import Foundation
import Testing
import PhotoEvidenceContracts
import PhotoEvidenceEngine
@testable import PhotoEvidenceUI

@Suite("Render source identity and mapping")
struct RenderSourceTests {
    let frame = CloseUpFrame(id: URL(filePath: "/fixture/a.raw"), name: "a.raw", revision: "file-v1")
    let jpg = CloseUpRenderSource(kind: .embeddedPreview, backendID: "jpg", revision: "1")
    let raw = CloseUpRenderSource(kind: .developedRAW, backendID: "raw9", revision: "exposure-v2")

    @Test func sourceAndSettingsParticipateInRequestIdentity() {
        let a = request(jpg), b = request(raw)
        #expect(a != b)
        #expect(a.frame == b.frame)
        #expect(request(raw) != request(CloseUpRenderSource(kind: .developedRAW, backendID: "raw9", revision: "exposure-v3")))
    }

    @Test func savedRegionDoesNotDependOnRenderRevision() {
        let region = CloseUpRegion(center: CGPoint(x: 0.2, y: 0.7), fraction: 0.2)
        let saved = CloseUpRegionRecord(frame: frame, region: region)
        #expect(saved.region(for: request(jpg).frame) == saved.region(for: request(raw).frame))
        #expect(saved.region(for: frame) == region)
    }

    @Test func cropTransformMapsCanonicalRegionAndCanBeInverted() {
        let transform = CloseUpCoordinateTransform(a: 2, d: 2, tx: -0.5, ty: -0.5)
        let region = CloseUpRegion(center: CGPoint(x: 0.4, y: 0.4), fraction: 0.1)
        let input = CloseUpRequest(frame: frame, region: region, mode: .fitRegion, displayScale: 2, renderSource: raw)
        let bounds = CloseUpCropGeometry.normalizedBounds(for: input, width: 1000, height: 1000,
            sourceToRenderTransform: transform)
        #expect(abs(bounds.midX - 0.3) < 0.002)
        #expect(abs(bounds.width - 0.2) < 0.002)
        let original = CGPoint(x: 0.4, y: 0.6)
        let restored = transform.inversePoint(transform.point(original))
        #expect(abs((restored?.x ?? 0) - original.x) < 0.000001)
        #expect(abs((restored?.y ?? 0) - original.y) < 0.000001)
    }

    @Test func regionOutsideDevelopedCropIsNotSilentlyMoved() throws {
        let context = try #require(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let input = CloseUpRequest(frame: frame, region: CloseUpRegion(center: CGPoint(x: 0.1, y: 0.1), fraction: 0.1),
            mode: .fitRegion, displayScale: 2, renderSource: raw)
        do {
            _ = try CloseUpRasterizer.render(image, request: input, sourceLabel: "RAW 9",
                sourceToRenderTransform: CloseUpCoordinateTransform(a: 2, d: 2, tx: -1, ty: -1))
            Issue.record("An excluded region must not show different pixels")
        } catch CloseUpRenderError.regionOutsideRender { }
    }

    @Test @MainActor func sourceSwitchDiscardsOldArtifactAndRejectsLateJPG() async {
        let provider = SourceGateRenderer()
        let model = CloseUpCardModel()
        let first = Task { await model.load(request(jpg), using: provider) }
        await provider.wait(jpg)
        let second = Task { await model.load(request(raw), using: provider) }
        await provider.wait(raw)
        #expect(model.render == nil)
        await provider.finish(raw, deliveredSource: raw)
        await second.value
        await provider.finish(jpg, deliveredSource: jpg)
        await first.value
        #expect(model.render?.renderSource == raw)
    }

    @Test @MainActor func mislabeledProviderResultIsRejected() async {
        let provider = SourceGateRenderer()
        let model = CloseUpCardModel()
        let loading = Task { await model.load(request(raw), using: provider) }
        await provider.wait(raw)
        await provider.finish(raw, deliveredSource: jpg)
        await loading.value
        #expect(model.render == nil)
        #expect(model.failure != nil)
    }

    private func request(_ source: CloseUpRenderSource) -> CloseUpRequest {
        CloseUpRequest(frame: frame, region: CloseUpRegion(), mode: .fitRegion,
                       displayScale: 2, renderSource: source)
    }
}

private actor SourceGateRenderer: CloseUpRendering {
    private var pending: [CloseUpRenderSource: CheckedContinuation<CloseUpRender, any Error>] = [:]
    private var arrivals: [CloseUpRenderSource: CheckedContinuation<Void, Never>] = [:]
    func render(_ request: CloseUpRequest) async throws -> CloseUpRender {
        try await withCheckedThrowingContinuation { continuation in
            pending[request.renderSource] = continuation
            arrivals.removeValue(forKey: request.renderSource)?.resume()
        }
    }
    func wait(_ source: CloseUpRenderSource) async {
        if pending[source] != nil { return }
        await withCheckedContinuation { arrivals[source] = $0 }
    }
    func finish(_ source: CloseUpRenderSource, deliveredSource: CloseUpRenderSource) {
        let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        pending.removeValue(forKey: source)?.resume(returning: CloseUpRender(crop: image, overview: image,
            sourceWidth: 8, sourceHeight: 8, sourceLabel: deliveredSource.backendID,
            displayedBounds: CGRect(x: 0, y: 0, width: 1, height: 1), renderSource: deliveredSource))
    }
}
