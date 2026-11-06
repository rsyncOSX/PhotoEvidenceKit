import Foundation
import CoreGraphics
import Testing
import PhotoEvidenceContracts
import PhotoEvidenceEngine
import PhotoEvidenceUI

@Suite("Comparison sessions") @MainActor
struct ComparisonSessionTests {
    let a = CloseUpFrame(id: URL(filePath: "/fixture/a.jpg"), name: "a", revision: "a-v1")
    let b = CloseUpFrame(id: URL(filePath: "/fixture/b.jpg"), name: "b", revision: "b-v1")
    let c = CloseUpFrame(id: URL(filePath: "/fixture/c.jpg"), name: "c", revision: "c-v1")

    @Test func referenceSurvivesSelectionAndCanBeReplaced() {
        let model = CloseUpModel()
        model.updateFrames([a, b])
        model.pin(a)
        #expect(model.comparisonFrames == [a, b])
        model.updateFrames([c])
        #expect(model.reference == a)
        #expect(model.comparisonFrames == [a, c])
        model.pin(c)
        #expect(model.comparisonFrames == [c])
        model.unpin()
        #expect(model.reference == nil)
        #expect(model.selectedFrames == [c])
    }

    @Test func linkingChangesInspectionWithoutCopyingSubjectCoordinates() {
        let model = CloseUpModel()
        model.updateFrames([a, b])
        let left = CloseUpRegion(center: CGPoint(x: 0.2, y: 0.3), fraction: 0.2)
        let right = CloseUpRegion(center: CGPoint(x: 0.7, y: 0.8), fraction: 0.3)
        model.setRegion(left, for: a.id)
        model.setRegion(right, for: b.id)
        let viewport = CloseUpViewport(offset: CGPoint(x: 0.1, y: -0.2), zoom: 2)
        model.setViewport(viewport, for: a.id)
        model.setLinked(true, around: a.id)
        #expect(model.viewport(for: b.id) == viewport)
        #expect(model.region(for: a.id) == left)
        #expect(model.region(for: b.id) == right)
        model.updateFrames([a, b, c])
        #expect(model.viewport(for: c.id) == viewport)
        model.setLinked(false)
        model.resetViewport(a.id)
        #expect(model.viewport(for: b.id) == viewport)
        #expect(model.viewport(for: a.id) == CloseUpViewport())
        model.resetViews()
        #expect(model.viewport(for: b.id) == CloseUpViewport())
        #expect(model.region(for: b.id) == right)
    }

    @Test func storedRegionsSurviveNavigationAndNewSessionButNotSourceReplacement() {
        let storage = MemoryRegionStore()
        let first = CloseUpModel(storage: storage)
        first.updateFrames([a])
        let chosen = CloseUpRegion(center: CGPoint(x: 0.2, y: 0.8), fraction: 0.2)
        first.setRegion(chosen, for: a.id)
        first.updateFrames([b])
        first.updateFrames([a])
        #expect(first.region(for: a.id) == chosen)
        let second = CloseUpModel(storage: storage)
        second.updateFrames([a])
        #expect(second.region(for: a.id) == chosen)
        second.updateFrames([CloseUpFrame(id: a.id, name: a.name, revision: "replaced")])
        #expect(second.region(for: a.id) == CloseUpRegion())
        #expect(first.reference == nil)
    }

    @Test func resetRegionIsPersistedWithoutChangingViewport() {
        let storage = MemoryRegionStore()
        let first = CloseUpModel(storage: storage)
        first.updateFrames([a])
        first.setRegion(CloseUpRegion(center: .zero, fraction: 0.1), for: a.id)
        first.setViewport(CloseUpViewport(zoom: 3), for: a.id)
        first.resetRegion(a.id)
        let second = CloseUpModel(storage: storage)
        second.updateFrames([a])
        #expect(second.region(for: a.id) == CloseUpRegion())
        #expect(first.viewport(for: a.id).zoom == 3)
    }

    @Test func failedSaveSurvivesNavigationAndCanBeRetried() {
        let storage = MemoryRegionStore()
        storage.failWrites = true
        let model = CloseUpModel(storage: storage)
        model.updateFrames([a])
        let chosen = CloseUpRegion(center: CGPoint(x: 0.7, y: 0.3), fraction: 0.2)
        model.setRegion(chosen, for: a.id)
        model.updateFrames([b])
        #expect(model.persistenceFailure != nil)
        storage.failWrites = false
        model.retrySaving()
        let restored = CloseUpModel(storage: storage)
        restored.updateFrames([a])
        #expect(restored.region(for: a.id) == chosen)
        #expect(model.persistenceFailure == nil)
    }

    @Test func incompatibleRecordDoesNotBecomeValidByMatchingURL() {
        let record = CloseUpRegionRecord(frame: a, region: CloseUpRegion(fraction: 0.1))
        #expect(record.region(for: CloseUpFrame(id: a.id, name: a.name, revision: "different")) == nil)
        #expect(record.region(for: b) == nil)
    }
}

@MainActor private final class MemoryRegionStore: CloseUpRegionStoring {
    var records: [URL: CloseUpRegionRecord] = [:]
    var failWrites = false
    func load(for frame: CloseUpFrame) throws -> CloseUpRegionRecord? { records[frame.id] }
    func save(_ record: CloseUpRegionRecord) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        records[record.sourceID] = record
    }
}
