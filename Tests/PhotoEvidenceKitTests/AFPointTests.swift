import CoreGraphics
import Foundation
import PhotoEvidenceContracts
import PhotoEvidenceUI
import Testing

@Suite("AF point assistance")
struct AFPointTests {
    private func frame(_ name: String = "a", revision: String = "1") -> CloseUpFrame {
        CloseUpFrame(id: URL(filePath: "/tmp/\(name).jpg"), name: name, revision: revision)
    }

    @Test(arguments: [CGPoint(x: Double.nan, y: 0), CGPoint(x: 0, y: Double.infinity),
                      CGPoint(x: -0.1, y: 0.5), CGPoint(x: 0.5, y: 1.1)])
    func rejectsInvalidMetadata(center: CGPoint) {
        #expect(CloseUpAFPoint(frame: frame(), center: center) == nil)
    }

    @Test @MainActor func placementIsLocalPersistentAndOneTime() throws {
        let a = frame(), b = frame("b")
        let store = AFRegionStore()
        let model = CloseUpModel(storage: store)
        model.updateFrames([a, b])
        model.setRegion(CloseUpRegion(fraction: 0.2), for: a.id)
        model.pin(a)
        model.updateFrames([b]) // Retained reference remains eligible.
        model.setLinked(true)
        model.setViewport(CloseUpViewport(offset: CGPoint(x: 0.1, y: 0.2), zoom: 2), for: b.id)
        let viewport = model.viewport(for: a.id)
        let target = try #require(CloseUpAFPoint(frame: a, center: CGPoint(x: 0.3, y: 0.7)))
        #expect(model.useAFPoint(target))
        #expect(model.region(for: a.id) == CloseUpRegion(center: target.center, fraction: 0.2))
        #expect(model.region(for: b.id) == CloseUpRegion())
        #expect(model.viewport(for: a.id) == viewport)
        #expect(model.viewport(for: b.id) == viewport)
        #expect(model.isLinked)
        #expect(model.reference == a)
        #expect(store.records[a.id]?.region(for: a) == model.region(for: a.id))
        model.setRegion(CloseUpRegion(), for: a.id)
        #expect(model.region(for: a.id) == CloseUpRegion()) // No ongoing snapping.
    }

    @Test @MainActor func enabledModeFollowsNavigationAndLateMetadataUntilDisabled() throws {
        let a = frame(), b = frame("b"), revised = frame("b", revision: "2")
        let model = CloseUpModel()
        let first = try #require(CloseUpAFPoint(frame: a, center: CGPoint(x: 0.3, y: 0.7)))
        let next = try #require(CloseUpAFPoint(frame: b, center: CGPoint(x: 0.6, y: 0.4)))
        model.updateFrames([a])
        model.updateAFPoints([a.id: .available(first)])
        model.setViewport(CloseUpViewport(offset: CGPoint(x: 0.1, y: 0.2), zoom: 2), for: a.id)
        model.usesAFPoint = true
        #expect(model.region(for: a.id).center == first.center)
        #expect(model.viewport(for: a.id).offset == .zero)
        #expect(model.viewport(for: a.id).zoom == 2)
        model.updateFrames([b])
        #expect(model.usesAFPoint)
        model.updateAFPoints([b.id: .available(next)])
        #expect(model.region(for: b.id).center == next.center)
        model.updateFrames([revised])
        #expect(model.region(for: b.id) == CloseUpRegion()) // Stale metadata cannot place a revised frame.
        model.usesAFPoint = false
        model.updateFrames([a])
        model.updateAFPoints([a.id: .available(first)])
        #expect(model.region(for: a.id) == CloseUpRegion())
    }

    @Test @MainActor func rejectsStaleAndInactiveTargets() throws {
        let old = frame(), updated = frame(revision: "2")
        let target = try #require(CloseUpAFPoint(frame: old, center: .zero))
        let model = CloseUpModel()
        model.updateFrames([updated])
        #expect(!model.useAFPoint(target))
        #expect(CloseUpAFPointAvailability.available(target).target(for: updated) == nil)
        model.updateFrames([])
        #expect(!model.useAFPoint(target))
        #expect(model.regions.isEmpty)
    }

    @Test @MainActor func edgePlacementClampsWithoutChangingSize() throws {
        let a = frame()
        let model = CloseUpModel()
        model.updateFrames([a])
        let target = try #require(CloseUpAFPoint(frame: a, center: CGPoint(x: 1, y: 0)))
        #expect(model.useAFPoint(target))
        #expect(model.region(for: a.id).bounds == CGRect(x: 0.75, y: 0, width: 0.25, height: 0.25))
        #expect(CloseUpAFPointAvailability.unavailable(reason: "No active AF point").target(for: a) == nil)
    }
}

@MainActor private final class AFRegionStore: CloseUpRegionStoring {
    var records: [URL: CloseUpRegionRecord] = [:]
    func load(for frame: CloseUpFrame) throws -> CloseUpRegionRecord? { records[frame.id] }
    func save(_ record: CloseUpRegionRecord) throws { records[record.sourceID] = record }
}
