# Architecture and extension policy

PhotoEvidenceContracts uses Foundation/CoreGraphics coordinate values only. It
contains no image buffers, SwiftUI, app view models or optional model runtimes.
PhotoEvidenceEngine consumes those values, implements crop geometry/rasterization
and declares the image-artifact rendering interface. PhotoEvidenceUI owns session
presentation and interaction. The app composes all services through adapters.
SwiftPM target dependencies enforce this direction.

The models never become the authoritative catalog/selection/decision repository.
Pinning and activating are distinct; linking viewports never transfers a subject
selection. Stored regions are photographer choices; rendered crops are evictable.
The rendering artifact type carries CGImage only across the rendering/UI boundary.

This first API implements manual comparison. Future evidence should add immutable,
revisioned source/region/metric snapshots, typed availability, explicit provider
capabilities and comparability policy. Keep masks/manual regions/AF location/detail
measurements/generated observations distinct. Add subject confirmation before
subject-based recommendations, and keep technical suggestions separate from manual
winners. AI providers must remain optional injected implementations.

Future app integrations should demonstrate the same component with two independent
hosts. The included synthetic demo and RawBrowse adapter establish that boundary;
RawCull review integration is a separate follow-up. Changing a renderer, storage
adapter or panel layout should leave unrelated targets unchanged.

Before tagging a public release: run debug tests and release build, review the
public symbols and storage schema, record supported toolchain/platform versions,
and run host image/orientation/performance qualification. API changes are expected
before the first release; no binary-stability guarantee is made.
