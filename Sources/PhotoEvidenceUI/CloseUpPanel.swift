import SwiftUI
import PhotoEvidenceContracts
import PhotoEvidenceEngine

/// Embeddable comparison panel. Host owns files, selection, image access and
/// durable decisions. No inference or rating changes are initiated by this view.
@MainActor public struct CloseUpPanel: View {
    private let frames: [CloseUpFrame]
    private let currentFrameID: URL?
    private let renderSources: [URL: CloseUpRenderSource]
    private let afPoints: [URL: CloseUpAFPointAvailability]
    private let model: CloseUpModel
    private let renderer: any CloseUpRendering
    private let onActivate: ((CloseUpFrame) -> Void)?
    private let onUseAFPoint: ((CloseUpFrame) -> Void)?
    private let onClose: () -> Void

    public init(frames: [CloseUpFrame], currentFrameID: URL? = nil, model: CloseUpModel,
                renderer: any CloseUpRendering, renderSources: [URL: CloseUpRenderSource] = [:],
                afPoints: [URL: CloseUpAFPointAvailability] = [:],
                onActivate: ((CloseUpFrame) -> Void)? = nil,
                onUseAFPoint: ((CloseUpFrame) -> Void)? = nil, onClose: @escaping () -> Void) {
        self.afPoints = afPoints
        self.renderSources = renderSources
        self.frames = frames
        self.currentFrameID = currentFrameID
        self.model = model
        self.renderer = renderer
        self.onUseAFPoint = onUseAFPoint
        self.onActivate = onActivate
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CloseUpPanelHeader(count: model.comparisonFrames.count, onClose: onClose)
            CloseUpPanelControls(model: model, currentFrameID: currentFrameID)
            if let failure = model.persistenceFailure {
                CloseUpPersistenceBanner(failure: failure, onRetry: model.retrySaving)
            }
            Divider()
            if model.comparisonFrames.isEmpty {
                ContentUnavailableView("Select images", systemImage: "rectangle.stack",
                    description: Text("Select one or more images to inspect them here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(model.comparisonFrames) { frame in
                            CloseUpCard(frame: frame,
                                isReference: frame.id == model.reference?.id,
                                isCurrent: frame.id == currentFrameID,
                                hasReference: model.reference != nil,
                                region: Binding(get: { model.region(for: frame.id) },
                                                set: { model.setRegion($0, for: frame.id) }),
                                viewport: Binding(get: { model.viewport(for: frame.id) },
                                                  set: { model.setViewport($0, for: frame.id) }),
                                mode: model.mode, renderSource: renderSources[frame.id] ?? .unspecified, renderer: renderer,
                                onPin: { model.pin(frame) }, onUnpin: model.unpin,
                                afPoint: afPoints[frame.id],
                                onUseAFPoint: { target in
                                    if model.useAFPoint(target) { onUseAFPoint?(frame) }
                                },
                                onResetRegion: { model.resetRegion(frame.id) },
                                onResetView: { model.resetViewport(frame.id) },
                                onActivate: frames.contains(where: { $0.id == frame.id })
                                    ? onActivate.map { activate in { activate(frame) } } : nil)
                        }
                    }.padding(12)
                }
            }
        }
        .frame(width: 304)
        .background(.background)
        .onChange(of: frames, initial: true) { _, updated in model.updateFrames(updated) }
    }
}

private struct CloseUpPanelHeader: View {
    let count: Int
    let onClose: () -> Void
    var body: some View {
        HStack {
            Text("Close-ups (\(count))").font(.headline)
            Spacer()
            Button("Close Close-ups", systemImage: "xmark", action: onClose).labelStyle(.iconOnly)
        }.padding(12)
    }
}

private struct CloseUpPanelControls: View {
    @Bindable var model: CloseUpModel
    let currentFrameID: URL?
    var body: some View {
        VStack(spacing: 8) {
            Picker("Inspection scale", selection: $model.mode) {
                Text("Fit region").tag(CloseUpScaleMode.fitRegion)
                Text("Source pixels").tag(CloseUpScaleMode.sourcePixels)
            }.pickerStyle(.segmented).labelsHidden()
            HStack {
                Toggle("Link pan/zoom", isOn: Binding(get: { model.isLinked },
                    set: { model.setLinked($0, around: currentFrameID) }))
                    .toggleStyle(.checkbox)
                    .help("Link inspection around each image's own manual region")
                Spacer()
                Button("Reset views", action: model.resetViews).controlSize(.small)
            }
            Text(model.mode == .fitRegion ? "Manual regions · magnification varies"
                                          : "Source pixels · zoom sets points per source pixel")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 12).padding(.bottom, 10)
    }
}

private struct CloseUpPersistenceBanner: View {
    let failure: String
    let onRetry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Region storage needs attention", systemImage: "exclamationmark.triangle")
            Text(verbatim: failure)
            Button("Retry saving regions", action: onRetry)
        }.font(.caption).padding(10)
    }
}

private struct CloseUpLoadKey: Equatable {
    let request: CloseUpRequest
    let retry: Int
}

private struct CloseUpCard: View {
    let frame: CloseUpFrame
    let isReference: Bool
    let isCurrent: Bool
    let hasReference: Bool
    @Binding var region: CloseUpRegion
    @Binding var viewport: CloseUpViewport
    let mode: CloseUpScaleMode
    let renderSource: CloseUpRenderSource
    let renderer: any CloseUpRendering
    let onPin: () -> Void
    let onUnpin: () -> Void
    let afPoint: CloseUpAFPointAvailability?
    let onUseAFPoint: (CloseUpAFPoint) -> Void
    let onResetRegion: () -> Void
    let onResetView: () -> Void
    let onActivate: (() -> Void)?
    @Environment(\.displayScale) private var displayScale
    @State private var model = CloseUpCardModel()
    @State private var retry = 0
    @State private var panAnchor: CloseUpViewport?

    private var request: CloseUpRequest {
        CloseUpRequest(frame: frame, region: region, mode: mode,
                       displayScale: displayScale, viewport: viewport, renderSource: renderSource)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isReference { Text("Reference").foregroundStyle(.blue).fontWeight(.semibold) }
                if isCurrent { Text("Current").fontWeight(.semibold) }
                if !isReference && !isCurrent { Text("Selected").foregroundStyle(.secondary) }
                Spacer()
            }.font(.caption)
            Text(frame.name).font(.caption.weight(.semibold)).lineLimit(1).help(frame.name)
            HStack {
                if isReference { Button("Unpin reference", action: onUnpin) }
                else { Button(hasReference ? "Replace reference" : "Pin reference", action: onPin) }
                Spacer()
                if let onActivate { Button("Show image", action: onActivate) }
            }.controlSize(.small)
            HStack {
                Text("Zoom").font(.caption)
                Slider(value: $viewport.zoom, in: 0.25 ... 8)
                    .accessibilityLabel("Inspection zoom for \(frame.name)")
                    .simultaneousGesture(TapGesture(count: 2).onEnded { viewport.zoom = CloseUpViewport().zoom })
                    .help("Double-click to reset zoom to 1×")
                Text(viewport.normalized.zoom.formatted(.number.precision(.fractionLength(2))) + "×")
                    .font(.caption.monospacedDigit()).frame(width: 44)
                Button("Reset view", action: onResetView).controlSize(.small)
            }
            HStack {
                Text("Region size").font(.caption)
                Slider(value: $region.fraction, in: 0.05 ... 1)
                    .accessibilityLabel("Manual region size for \(frame.name)")
                    .simultaneousGesture(TapGesture(count: 2).onEnded { region.fraction = CloseUpRegion().fraction })
                    .help("Double-click to reset region size to 25%")
                Button("Reset region", action: onResetRegion).controlSize(.small)
            }
            if let afPoint {
                Button("Use AF point") {
                    if let target = afPoint.target(for: frame) { onUseAFPoint(target) }
                }
                .controlSize(.small)
                .disabled(afPoint.target(for: frame) == nil)
                .help(afPoint.explanation(for: frame))
                .accessibilityLabel("Use AF point for \(frame.name)")
                .accessibilityHint(afPoint.explanation(for: frame))
                if afPoint.target(for: frame) == nil {
                    Text(verbatim: afPoint.explanation(for: frame))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("Overview: choose region. Crop: drag or use arrow keys to pan.").font(.caption2).foregroundStyle(.secondary)
            ZStack {
                Rectangle().fill(.black)
                if let render = model.render {
                    if mode == .sourcePixels {
                        Image(decorative: render.crop, scale: 1).resizable()
                            .frame(width: render.displayedBounds.width * Double(render.sourceWidth) * viewport.normalized.zoom,
                                   height: render.displayedBounds.height * Double(render.sourceHeight) * viewport.normalized.zoom)
                    } else {
                        Image(decorative: render.crop, scale: displayScale).resizable().scaledToFit()
                    }
                } else if model.isLoading {
                    ProgressView().tint(.white)
                } else { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
            .frame(width: 280, height: 210).clipped().contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3).onChanged { value in
                guard let render = model.render else { return }
                if panAnchor == nil { panAnchor = viewport }
                guard let initial = panAnchor else { return }
                let initialRequest = CloseUpRequest(frame: frame, region: region, mode: mode,
                    displayScale: displayScale, viewport: initial, renderSource: renderSource)
                viewport = CloseUpCropGeometry.pannedViewport(initial, translation: value.translation,
                    request: initialRequest, sourceWidth: render.sourceWidth, sourceHeight: render.sourceHeight,
                    sourceToRenderTransform: render.sourceToRenderTransform)
            }.onEnded { _ in panAnchor = nil })
            .overlay(alignment: .topTrailing) {
                if model.isLoading, model.render != nil { ProgressView().controlSize(.small).padding(8) }
            }
            .focusable()
            .onMoveCommand { direction in
                var updated = viewport.normalized
                switch direction {
                case .left: updated.offset.x -= 0.05
                case .right: updated.offset.x += 0.05
                case .up: updated.offset.y -= 0.05
                case .down: updated.offset.y += 0.05
                @unknown default: return
                }
                viewport = updated.normalized
            }
            .help("Tab to the crop, then use arrow keys to pan")
            .accessibilityLabel("Inspection crop for \(frame.name)")
            .accessibilityHint("Drag to pan the inspection, or focus the crop and use arrow keys. Use the zoom slider to adjust magnification.")
            if let render = model.render {
                CloseUpOverview(image: render.overview, bounds: CloseUpCropGeometry.normalizedBounds(
                    for: request, width: render.sourceWidth, height: render.sourceHeight,
                    sourceToRenderTransform: render.sourceToRenderTransform)) { center in
                        let displayed = CloseUpCropGeometry.normalizedBounds(for: request,
                            width: render.sourceWidth, height: render.sourceHeight,
                            sourceToRenderTransform: render.sourceToRenderTransform)
                        guard let desired = render.sourceToRenderTransform.inversePoint(center),
                              let previous = render.sourceToRenderTransform.inversePoint(CGPoint(x: displayed.midX, y: displayed.midY)) else { return }
                        region.center = CGPoint(x: region.center.x + desired.x - previous.x,
                                                y: region.center.y + desired.y - previous.y)
                    }
                Text("\(render.sourceLabel) · \(render.sourceWidth) × \(render.sourceHeight)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let failure = model.failure {
                Text(verbatim: failure).font(.caption).foregroundStyle(.secondary)
                Button("Retry image") { retry += 1 }
            }
            Divider()
        }
        .task(id: CloseUpLoadKey(request: request, retry: retry)) { await model.load(request, using: renderer) }
        .onDisappear { model.release() }
    }
}

private struct CloseUpOverview: View {
    let image: CGImage
    let bounds: CGRect
    let onCenter: (CGPoint) -> Void
    @State private var dragAnchor: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Double(image.width),
                            geometry.size.height / Double(image.height))
            let size = CGSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
            let origin = CGPoint(x: (geometry.size.width - size.width) / 2,
                                 y: (geometry.size.height - size.height) / 2)
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1).resizable().frame(width: size.width, height: size.height)
                Rectangle().stroke(.blue, lineWidth: 2)
                    .frame(width: bounds.width * size.width, height: bounds.height * size.height)
                    .offset(x: bounds.minX * size.width, y: bounds.minY * size.height)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard size.width > 0, size.height > 0 else { return }
                    if dragAnchor == nil {
                        let start = CGPoint(x: value.startLocation.x / size.width,
                                            y: value.startLocation.y / size.height)
                        // Preserve the grab offset when dragging inside the region.
                        // Clicking elsewhere centers the region under the pointer.
                        dragAnchor = bounds.contains(start)
                            ? CGPoint(x: bounds.midX, y: bounds.midY) : start
                    }
                    guard let anchor = dragAnchor else { return }
                    onCenter(CGPoint(
                        x: min(1, max(0, anchor.x + value.translation.width / size.width)),
                        y: min(1, max(0, anchor.y + value.translation.height / size.height))))
                }
                .onEnded { _ in dragAnchor = nil })
            .offset(x: origin.x, y: origin.y)
            .accessibilityLabel("Manual region overview")
            .accessibilityHint("Click or drag to move the region.")
        }
        .frame(height: 110)
    }
}
