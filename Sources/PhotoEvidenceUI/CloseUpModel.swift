import Foundation
import Observation
import PhotoEvidenceContracts

/// Session interaction state only. Selection, ratings and photographer winners
/// remain host-owned. Pinning is temporary and never sets a winner or rating.
@MainActor @Observable public final class CloseUpModel {
    /// Session preference shared by all close-ups; hosts can synchronize their AF overlay.
    public var usesAFPoint = false {
        didSet { if usesAFPoint { applyAFPoints() } }
    }
    @ObservationIgnored private var afPoints: [URL: CloseUpAFPointAvailability] = [:]
    public var mode: CloseUpScaleMode = .fitRegion
    public private(set) var isLinked = false
    public private(set) var reference: CloseUpFrame?
    public private(set) var selectedFrames: [CloseUpFrame] = []
    public private(set) var persistenceFailure: String?
    public private(set) var regions: [URL: CloseUpRegion] = [:]
    private var viewports: [URL: CloseUpViewport] = [:]
    @ObservationIgnored private let storage: (any CloseUpRegionStoring)?
    @ObservationIgnored private var knownFrames: [URL: CloseUpFrame] = [:]
    @ObservationIgnored private var pendingSaves: [URL: CloseUpRegionRecord] = [:]
    @ObservationIgnored private var sharedViewport = CloseUpViewport()

    public init(storage: (any CloseUpRegionStoring)? = nil) { self.storage = storage }

    /// Reference appears once, even if also selected, and survives navigation.
    public var comparisonFrames: [CloseUpFrame] {
        (reference.map { [$0] } ?? []) + selectedFrames.filter { $0.id != reference?.id }
    }

    public func region(for id: URL) -> CloseUpRegion { regions[id] ?? CloseUpRegion() }
    public func viewport(for id: URL) -> CloseUpViewport { viewports[id] ?? (isLinked ? sharedViewport : CloseUpViewport()) }

    public func updateFrames(_ frames: [CloseUpFrame]) {
        var seen = Set<URL>()
        selectedFrames = frames.filter { seen.insert($0.id).inserted }
        if let old = reference, let updated = selectedFrames.first(where: { $0.id == old.id }) {
            reference = updated
        }
        for frame in comparisonFrames {
            if knownFrames[frame.id]?.revision == frame.revision { continue }
            regions[frame.id] = nil
            viewports[frame.id] = nil
            if let pending = pendingSaves[frame.id], pending.sourceRevision == frame.revision {
                regions[frame.id] = pending.region
            } else {
                do {
                    regions[frame.id] = try storage?.load(for: frame)?.region(for: frame)
                } catch { persistenceFailure = error.localizedDescription }
            }
            knownFrames[frame.id] = frame
        }
        trimInactiveState()
        applyAFPoints()
    }

    /// Changes a manual region only for this frame; linking never copies regions.
    public func setRegion(_ region: CloseUpRegion, for id: URL) {
        regions[id] = region.normalized
        guard let frame = knownFrames[id] else { return }
        persist(CloseUpRegionRecord(frame: frame, region: region))
    }

    /// One-time manual-region placement. Preserves size, viewport and linked state;
    /// edge targets are clamped by the normal region bounds policy.
    /// Returns false for inactive frames or metadata from an obsolete revision.
    @discardableResult public func useAFPoint(_ target: CloseUpAFPoint) -> Bool {
        guard comparisonFrames.contains(target.frame), knownFrames[target.frame.id] == target.frame else { return false }
        var region = region(for: target.frame.id)
        region.center = target.center
        setRegion(region, for: target.frame.id)
        return true
    }

    /// Refresh metadata independently of selection, including asynchronously loaded AF points.
    public func updateAFPoints(_ points: [URL: CloseUpAFPointAvailability]) {
        afPoints = points
        applyAFPoints()
    }

    private func applyAFPoints() {
        guard usesAFPoint else { return }
        for frame in comparisonFrames {
            guard let target = afPoints[frame.id]?.target(for: frame) else { continue }
            var region = region(for: frame.id)
            region.center = target.center
            if region.normalized != self.region(for: frame.id) {
                setRegion(region, for: frame.id)
            }
            // A previously panned viewport must not displace the AF point from the center.
            if viewport(for: frame.id).offset != .zero {
                var viewport = viewport(for: frame.id)
                viewport.offset = .zero
                setViewport(viewport, for: frame.id)
            }
        }
    }

    public func resetRegion(_ id: URL) { setRegion(CloseUpRegion(), for: id) }

    public func pin(_ frame: CloseUpFrame) {
        guard selectedFrames.contains(frame) || reference == frame else { return }
        reference = frame
        knownFrames[frame.id] = frame
        trimInactiveState()
    }

    /// Refresh a pinned source without adding it to host selection.
    public func updateReference(_ frame: CloseUpFrame) {
        guard reference?.id == frame.id else { return }
        reference = frame
        updateFrames(selectedFrames)
    }

    public func unpin() { reference = nil; trimInactiveState() }

    /// Linking applies relative offsets/zoom around each independent region.
    public func setLinked(_ linked: Bool, around id: URL? = nil) {
        guard linked != isLinked else { return }
        if linked {
            sharedViewport = id.map { viewport(for: $0) } ?? CloseUpViewport()
            for frame in comparisonFrames { viewports[frame.id] = sharedViewport }
        }
        isLinked = linked
    }

    public func setViewport(_ viewport: CloseUpViewport, for id: URL) {
        guard knownFrames[id] != nil else { return }
        let value = viewport.normalized
        if isLinked {
            sharedViewport = value
            for frame in comparisonFrames { viewports[frame.id] = value }
        } else { viewports[id] = value }
    }

    public func resetViewport(_ id: URL) { setViewport(CloseUpViewport(), for: id) }
    public func resetViews() {
        sharedViewport = CloseUpViewport()
        for frame in comparisonFrames { viewports[frame.id] = CloseUpViewport() }
    }

    public func retrySaving() {
        for record in Array(pendingSaves.values) { persist(record) }
        // Retrying loads uses updateFrames after discarding the failed read cache.
        if pendingSaves.isEmpty {
            persistenceFailure = nil
            let active = comparisonFrames
            for frame in active where regions[frame.id] == nil { knownFrames[frame.id] = nil }
            updateFrames(selectedFrames)
        }
        trimInactiveState()
    }

    private func persist(_ record: CloseUpRegionRecord) {
        guard let storage else { return }
        do {
            try storage.save(record)
            pendingSaves[record.sourceID] = nil
            if pendingSaves.isEmpty { persistenceFailure = nil }
        } catch {
            pendingSaves[record.sourceID] = record
            persistenceFailure = error.localizedDescription
        }
    }

    private func trimInactiveState() {
        let keep = Set(comparisonFrames.map(\.id)).union(pendingSaves.keys)
        knownFrames = knownFrames.filter { keep.contains($0.key) }
        regions = regions.filter { keep.contains($0.key) }
        viewports = viewports.filter { keep.contains($0.key) }
    }
}
