# Host integration contract

## Inputs and identity

Supply ordered `CloseUpFrame` values. A frame's URL is its canonical, stable source
identity; its string revision must survive app restarts and change on source
replacement/edit/orientation-affecting changes. A catalog session UUID is not a
source revision. The current API is file-oriented; hosts with database or network
identities should resolve those to stable source URLs or propose an explicit ID
extension before changing identity semantics.

Metadata/fingerprint reads and image decoding belong off the main actor under
host-managed access leases. A URL is not a permission grant. When the host source
changes, supply an updated frame revision; the model invalidates its dependent
region/view state. Handle moved-file identity deliberately: this initial version
treats a new canonical URL as a different source.

`CloseUpPanel` receives selected frames plus an optional current ID. Pinning retains
one frame outside subsequent selections without changing the host's selection.
The reference is shown once, first, and is session-only. The optional activation
callback receives an explicit frame, is offered for selected inputs, and must be
validated against authoritative host selection. No ratings or winners are inferred.

## Coordinate and rendering rules

All regions use orientation-normalized image coordinates, origin top-left, x right
and y down. The host must apply rotation/mirroring exactly once before calling
`CloseUpRasterizer`; using image dimensions without the orientation transform is
insufficient. Masks, AF overlays and other future evidence need the same contract.

Implement `CloseUpRendering` with an async, Sendable service. Capture the requested
source revision, acquire access, check source identity/fingerprint before and after
loading, then run `CloseUpRasterizer.render` off the UI actor. Supply the actual
source label. The returned crop and overview are independent raster buffers, not
slices that retain an entire decoded source. Default artifacts are capped at
1120 pixels per longest edge (280 points × maximum display scale 4); custom request
sizes require a separate caller budget. Decoder/source cache limits remain host-owned.

Fit region varies magnification. Source pixels uses zoom as points per source
pixel, independent of backing scale. At zoom 1, a 280-source-pixel span occupies
280 display points. The backing scale controls raster output resolution, not that
ratio. `CloseUpCropGeometry` supplies the exact sampled/overlay bounds and pan math
for both renderer and view, including portrait letterboxing and edge clipping.

## Linked inspection

Manual region choices are always independent. `CloseUpViewport` is temporary zoom
and offset around each chosen region; offsets are region-relative, not global
image coordinates. Linking uses the current frame's viewport as an initial anchor,
then applies inspection changes to the working set and reference. New candidates
inherit the shared viewport. Unlink keeps each view where it is. Reset view resets
one view, or all linked views; Reset views resets the working set. Reset region
changes and saves only the selected frame's manual region.

Linked movement is a viewing convenience, not optical registration or subject
matching. Subjects must still be chosen/corrected independently in moving bursts.

## Persistence

Inject a `CloseUpRegionStoring` object into the model. This is a main-actor,
preference-sized synchronous boundary: use cached/hydrated storage, not synchronous
large file I/O. It exchanges versioned `CloseUpRegionRecord` values bound to URL
and source revision. The model restores a record only if schema, source and revision
match. The host adapter owns the physical store, permissions and migrations.

Each region change saves a small normalized record; a reset saves the default
region deliberately. Pin state, zoom and pan are session state and are not stored.
Failures remain visible, retain unsaved records across selection changes and can
be retried. A host with asynchronous transactional storage should provide a hydrated
adapter with explicit write-through guarantees or extend the contract rather than
pretend an uncommitted background save succeeded. This initial contract is designed
for app preferences, not a database transaction system.

Never store source images, security-scoped grants, AI caches or photographer rating
state in the region record. The app's existing decision repository stays authoritative.

## Lifecycle

The host owns one `CloseUpModel` per review session and one suitably bounded renderer.
The panel reconciles frame updates; programmatic clients call `updateFrames` before
editing regions. Closing a panel releases card artifacts/cancels its view tasks but
can preserve the host-owned model and pin. App relaunch creates a new model and
restores regions through the store. Navigation does not require retaining decoded
images. Provider cancellation is advisory; card generation checks prevent a late
result from replacing the currently requested evidence.
