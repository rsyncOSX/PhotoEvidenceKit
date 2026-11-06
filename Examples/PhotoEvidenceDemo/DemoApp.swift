import SwiftUI
import PhotoEvidenceContracts
import PhotoEvidenceEngine
import PhotoEvidenceUI

@main struct PhotoEvidenceDemoApp: App {
    var body: some Scene {
        WindowGroup("PhotoEvidenceKit Demo") { DemoWorkspace() }
            .defaultSize(width: 1080, height: 900)
    }
}

/// This consumer uses only public API and synthetic images, with no host app.
@MainActor private struct DemoWorkspace: View {
    private static let samples = [
        CloseUpFrame(id: URL(string: "fixture:///landscape")!, name: "Landscape", revision: "fixture-v1"),
        CloseUpFrame(id: URL(string: "fixture:///portrait")!, name: "Portrait", revision: "fixture-v1"),
        CloseUpFrame(id: URL(string: "fixture:///alternative")!, name: "Alternative", revision: "fixture-v1"),
    ]
    @State private var model = CloseUpModel(storage: DemoRegionStore())
    @State private var selected: Set<URL> = Set(Self.samples.prefix(2).map(\.id))
    @State private var current = Self.samples[0]
    @State private var panelVisible = true
    @State private var image: CGImage?
    private let renderer = DemoRenderer()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("PhotoEvidenceKit").font(.largeTitle)
                Text("Synthetic fixtures · no photos or AI models required").foregroundStyle(.secondary)
                ForEach(Self.samples) { frame in
                    HStack {
                        Toggle(frame.name, isOn: Binding(get: { selected.contains(frame.id) }, set: { value in
                            if value { selected.insert(frame.id) } else { selected.remove(frame.id) }
                        }))
                        Button("Preview \(frame.name)") { current = frame }
                    }.frame(maxWidth: 400)
                }
                Text("Current: \(current.name)")
                if let image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
                if !panelVisible { Button("Open Close-ups") { panelVisible = true } }
                Text("Pin a reference, deselect it, then link inspection. Each region stays independent.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            if panelVisible {
                Divider()
                CloseUpPanel(frames: Self.samples.filter { selected.contains($0.id) }, currentFrameID: current.id,
                    model: model, renderer: renderer, onActivate: { current = $0 }, onClose: { panelVisible = false })
            }
        }
        .frame(minWidth: 820, minHeight: 650)
        .task(id: current.id) { image = await renderer.source(for: current) }
    }
}

private actor DemoRenderer: CloseUpRendering {
    func source(for frame: CloseUpFrame) -> CGImage? {
        let portrait = frame.name == "Portrait"
        let width = portrait ? 1000 : 1600
        let height = portrait ? 1600 : 1000
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.12, green: 0.2, blue: 0.28, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for i in 0 ..< 12 {
            context.setFillColor(CGColor(red: Double(i) / 14, green: 0.5, blue: 0.6, alpha: 1))
            context.fill(CGRect(x: i * 140, y: 0, width: 20, height: height))
        }
        context.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.15, alpha: 1))
        context.fillEllipse(in: CGRect(x: width / 3, y: height / 3, width: 260, height: 260))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: width / 3 + 70, y: height / 3 + 70, width: 70, height: 70))
        return context.makeImage()
    }

    func render(_ request: CloseUpRequest) async throws -> CloseUpRender {
        guard let image = source(for: request.frame) else { throw CloseUpRenderError.unavailable }
        return try CloseUpRasterizer.render(image, request: request, sourceLabel: "Synthetic fixture")
    }
}

@MainActor private final class DemoRegionStore: CloseUpRegionStoring {
    private var records: [URL: CloseUpRegionRecord] = [:]
    func load(for frame: CloseUpFrame) throws -> CloseUpRegionRecord? { records[frame.id] }
    func save(_ record: CloseUpRegionRecord) throws { records[record.sourceID] = record }
}
