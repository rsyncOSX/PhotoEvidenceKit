# PhotoEvidenceKit

A modular Swift package for inspecting and comparing selected image regions in
macOS apps. It provides an embeddable SwiftUI Close-ups panel while the host keeps
ownership of image loading, file access, selection, persistence and review decisions.

**Requirements:** Swift 6.2+, macOS 26+. **Status:** initial, unreleased API.
MIT licensed; extracted from RawBrowse with the original attribution preserved.
There are no external package dependencies or bundled models/images.

## Features

- Independent manual regions, overview click/drag and keyboard controls.
- Fit-region and explicit source-pixel scales, with crop/source attribution.
- Pin, replace and unpin a reference that survives selection changes.
- Current/reference labels; optional explicit host activation action.
- Linked or independent pan/zoom around each frame's own region; reset controls.
- Source-bound, versioned saved-region records through an injected store.
- Explicit render-source/settings revisions, validated results and crop/straighten coordinate mapping.
- Generation/cancellation checks and bounded, independently owned raster artifacts.

This package does not decode RAW files, identify subjects, track animals, score
sharpness, recommend winners or write ratings/XMP. Several displayed frames are
inspection inputs, not automatically comparable measurements. Embedded-preview
pixels and developed-RAW pixels must be labeled truthfully by the host renderer.

## Products

| Import | Responsibility |
| --- | --- |
| `PhotoEvidenceContracts` | Sendable value requests, frames, manual regions, relative viewports and storage contract |
| `PhotoEvidenceEngine` | Shared pure crop geometry, bounded rasterization and async rendering interface |
| `PhotoEvidenceUI` | SwiftUI panel and main-actor comparison-session model |

Dependencies flow UI → Engine → Contracts, with UI also importing Contracts.
Contracts contain no SwiftUI views or image buffers. Engine has no app models,
filesystem access or inference dependencies. No product imports RawBrowse/RawCull.

## Add to an app

Add this directory as a local Swift package in Xcode and link the products your
app imports. For sibling repositories, the local reference is `../PhotoEvidenceKit`.
After publishing the repository, consumers can add its URL through Xcode or use a
SwiftPM package dependency with the published version; this package assumes no
particular GitHub owner, remote URL or release tag.

```swift
import SwiftUI
import PhotoEvidenceContracts
import PhotoEvidenceEngine
import PhotoEvidenceUI

@MainActor struct ComparisonView: View {
    let frames: [CloseUpFrame]       // host-owned stable URL identities/revisions
    let renderer: any CloseUpRendering
    @State private var model = CloseUpModel()

    var body: some View {
        CloseUpPanel(frames: frames, model: model, renderer: renderer,
                     onClose: { /* host hides the panel */ })
    }
}
```

The panel has a 304-point width and a 280 × 210-point crop viewport. Embed it on
either side of the host workspace. The library does not choose its position.
For selectable render pipelines, pass `renderSources: [URL: CloseUpRenderSource]`
to the panel. Changing a descriptor rerenders its card without changing the frame's
file revision or saved region. The host renderer returns the same descriptor;
`CloseUpRasterizer` supplies it automatically and accepts an optional canonical-to-render
coordinate transform for developed crop/straightening. RAW decoding remains host-owned.
Use `CloseUpModel(storage: yourStore)` to enable durable regions. Without a store,
regions exist only in the current/pinned working set. See [Integration](Documentation/Integration.md)
for the data and lifecycle contract, and [Architecture](Documentation/Architecture.md)
for extension boundaries.

## Run the independent example

```sh
swift run PhotoEvidenceDemo
```

The example imports only public APIs and generates its own portrait/landscape
fixtures. Select images with checkboxes, pin one, deselect it, then move/zoom a
candidate with linking enabled. It uses an in-memory region store for the demo;
production durability is supplied by the app adapter.

## Tests and release checks

```sh
swift test
swift build -c release
```

Tests cover pin/replace/unpin, linked inspection without copied regions, stored
choices across sessions and source changes, persistence retry, geometry bounds,
source-pixel scale, bounded artifacts and out-of-order/cancelled providers.
The public example is also a compile check for the exported API.

Before a production release, qualify portrait/rotation/mirroring at the host
render boundary, mixed source classes, smaller previews, rapid selection and
scrolling, memory pressure and measured cold/warm latency. The panel loads cards
lazily and releases offscreen artifacts; the host must bound source decoding,
cache memory and concurrency. Lazy views alone are not a memory budget.

## License

[MIT](LICENSE), copyright 2026 Thomas Evensen.
