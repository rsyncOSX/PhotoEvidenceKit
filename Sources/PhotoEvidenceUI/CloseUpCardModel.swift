import Foundation
import Observation
import PhotoEvidenceContracts
import PhotoEvidenceEngine

@MainActor @Observable
final class CloseUpCardModel {
    private(set) var render: CloseUpRender?
    private(set) var failure: String?
    private(set) var isLoading = false
    private var generation = 0
    @ObservationIgnored private var displayedSource: CloseUpRenderSource?
    @ObservationIgnored private var displayedFrame: CloseUpFrame?

    func load(_ request: CloseUpRequest, using renderer: any CloseUpRendering) async {
        generation += 1
        let current = generation
        // Keep the overview mounted during region edits so an active drag is
        // not destroyed by its own asynchronous crop request.
        if displayedFrame != request.frame || displayedSource != request.renderSource { render = nil }
        displayedSource = request.renderSource
        displayedFrame = request.frame
        failure = nil
        isLoading = true
        do {
            let result = try await renderer.render(request)
            guard !Task.isCancelled, current == generation else { return }
            guard result.renderSource == request.renderSource,
                  result.sourceWidth > 0, result.sourceHeight > 0,
                  result.sourceToRenderTransform.isValid else { throw CloseUpRenderError.renderMismatch }
            render = result
        } catch {
            guard !Task.isCancelled, current == generation else { return }
            failure = error.localizedDescription
        }
        if current == generation { isLoading = false }
    }

    func release() {
        displayedFrame = nil
        displayedSource = nil
        generation += 1
        render = nil
        failure = nil
        isLoading = false
    }
}
