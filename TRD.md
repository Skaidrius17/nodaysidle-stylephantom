# Technical Requirements Document

## 🧭 System Context
Style Phantom is a local-first macOS creative intelligence app (macOS 15+ Sequoia) built with SwiftUI 6, SwiftData, Core ML, and Metal. It analyzes a creator's body of work to map aesthetic taste evolution and project future style directions. All processing is on-device with zero network dependency for core functionality. Architecture is single-process with clean layered design: SwiftUI 6 presentation, Observation framework view models, domain services layer, Core ML inference layer, and SwiftData persistence with optional CloudKit sync. Swift 6 strict concurrency throughout with full Sendable compliance.

## 🔌 API Contracts
### ArtifactImportService.importArtifacts
- **Method:** async
- **Path:** Services/ArtifactImportService.swift
- **Auth:** NSOpenPanel file access + sandbox read permissions
- **Request:** func importArtifacts(from urls: [URL], into context: ModelContext) -> AsyncThrowingStream<ImportProgress, Error> where ImportProgress = (current: Int, total: Int, artifact: CreativeArtifact?)
- **Response:** AsyncThrowingStream yielding ImportProgress for each processed file. Final yield has current == total. Each successful artifact is inserted into the ModelContext immediately.
- **Errors:** ImportError.unsupportedFormat(URL), ImportError.fileTooLarge(URL, maxBytes: Int), ImportError.thumbnailGenerationFailed(URL), ImportError.duplicateArtifact(existingID: PersistentIdentifier)

### ArtifactImportService.generateThumbnail
- **Method:** async
- **Path:** Services/ArtifactImportService.swift
- **Auth:** File system sandbox read
- **Request:** func generateThumbnail(for imageURL: URL, maxDimension: CGFloat = 512) async throws -> CGImage
- **Response:** CGImage scaled to fit within maxDimension while preserving aspect ratio. Uses vImage for fast resizing.
- **Errors:** ImportError.unsupportedFormat(URL), ImportError.thumbnailGenerationFailed(URL)

### StyleVectorExtractor.extractVector
- **Method:** async
- **Path:** Services/StyleVectorExtractor.swift
- **Auth:** None (in-process Core ML)
- **Request:** func extractVector(from image: CGImage) async throws -> StyleVector where StyleVector is a struct with fields: colorPalette: [SIMD4<Float>] (5 dominant colors as RGBA), composition: SIMD8<Float> (rule-of-thirds, symmetry, focal-point, negative-space, depth, layering, balance, flow), texture: SIMD4<Float> (roughness, grain, sharpness, pattern-density), complexity: Float (0.0-1.0 scalar)
- **Response:** StyleVector with all fields populated from Core ML inference. Total dimensionality: 20+8+4+1 = 33 floats.
- **Errors:** ExtractionError.modelNotLoaded, ExtractionError.inferenceFailed(underlying: Error), ExtractionError.invalidImageDimensions(width: Int, height: Int)

### StyleVectorExtractor.batchExtract
- **Method:** async
- **Path:** Services/StyleVectorExtractor.swift
- **Auth:** None
- **Request:** func batchExtract(from artifacts: [CreativeArtifact], context: ModelContext, concurrency: Int = 4) -> AsyncThrowingStream<(CreativeArtifact, StyleVector), Error>
- **Response:** Stream of (artifact, vector) pairs as each extraction completes. Uses TaskGroup with bounded concurrency. Updates artifact.styleVectorData in-place.
- **Errors:** ExtractionError.modelNotLoaded, ExtractionError.inferenceFailed(underlying: Error)

### EvolutionEngine.computePhases
- **Method:** async
- **Path:** Services/EvolutionEngine.swift
- **Auth:** None
- **Request:** func computePhases(from artifacts: [CreativeArtifact], clusterCount: Int? = nil) async throws -> [AestheticPhase] where clusterCount nil triggers elbow-method auto-detection (k=2..10)
- **Response:** Array of AestheticPhase sorted chronologically by dateRange.lowerBound. Each phase contains centroidVector, dateRange, and references to member artifacts. Phases are inserted into ModelContext.
- **Errors:** EvolutionError.insufficientArtifacts(minimum: 5, actual: Int), EvolutionError.missingStyleVectors(artifactIDs: [PersistentIdentifier]), EvolutionError.clusteringFailed(underlying: Error)

### EvolutionEngine.computeTrajectory
- **Method:** async
- **Path:** Services/EvolutionEngine.swift
- **Auth:** None
- **Request:** func computeTrajectory(from phases: [AestheticPhase]) async -> StyleTrajectory where StyleTrajectory = (vectors: [StyleVector], velocity: StyleVector, acceleration: StyleVector)
- **Response:** StyleTrajectory containing ordered centroid vectors, velocity (first derivative of movement between centroids), and acceleration (second derivative showing whether taste is converging or diverging).
- **Errors:** EvolutionError.insufficientPhases(minimum: 2, actual: Int)

### ProjectionGenerator.generateProjection
- **Method:** async
- **Path:** Services/ProjectionGenerator.swift
- **Auth:** None
- **Request:** func generateProjection(from trajectory: StyleTrajectory, steps: Int = 1) async throws -> [StyleProjection]
- **Response:** Array of StyleProjection (one per step). Each contains: projectedVector (StyleVector), generatedPalette ([PaletteColor] with hex + name), layoutSuggestion (LayoutGrid with columns, rows, spacing, aspect ratios), structuralNotes (String describing compositional recommendations), confidence (Float 0.0-1.0 decaying per step).
- **Errors:** ProjectionError.insufficientTrajectoryData, ProjectionError.projectionOutOfBounds(step: Int)

### ExportService.exportPalette
- **Method:** async
- **Path:** Services/ExportService.swift
- **Auth:** NSSavePanel file access + sandbox write permissions
- **Request:** func exportPalette(_ projection: StyleProjection, format: PaletteExportFormat, to url: URL) async throws where PaletteExportFormat = .ase | .json | .css | .swiftColorAsset
- **Response:** File written to url in the requested format. Returns Void on success.
- **Errors:** ExportError.writePermissionDenied(URL), ExportError.encodingFailed(format: PaletteExportFormat)

### ExportService.exportLayout
- **Method:** async
- **Path:** Services/ExportService.swift
- **Auth:** NSSavePanel file access + sandbox write permissions
- **Request:** func exportLayout(_ projection: StyleProjection, format: LayoutExportFormat, to url: URL) async throws where LayoutExportFormat = .svg | .json | .figmaTokens
- **Response:** File written to url. SVG contains grid lines and spacing annotations. JSON is design-token compatible.
- **Errors:** ExportError.writePermissionDenied(URL), ExportError.encodingFailed(format: LayoutExportFormat)

## 🧱 Modules
### StylePhantomApp
- **Responsibilities:**
- App entry point with @main
- ModelContainer configuration and injection via .modelContainer modifier
- WindowGroup scene with NavigationSplitView root
- Settings scene for UserPreferences
- MenuBarExtra for quick artifact import
- NSWindow customization (.ultraThinMaterial vibrancy) via NSApplicationDelegateAdaptor
- **Interfaces:**
- @main struct StylePhantomApp: App
- **Dependencies:**
- PresentationLayer
- DataLayer

### PresentationLayer
- **Responsibilities:**
- SidebarView: NavigationSplitView sidebar showing AestheticPhase list with timeline scrubber
- ArtifactGalleryView: LazyVGrid of artifact thumbnails with matchedGeometryEffect transitions to detail
- EvolutionViewerView: Side-by-side comparison of current phase vs projected next phase with drag-to-refine interaction
- TimelineScrubberView: TimelineView + Metal shader rendering for 60fps phase timeline visualization
- ImportSheetView: Sheet for drag-and-drop or file picker artifact import with progress indicator
- ProjectionConfigSheet: Sheet for configuring projection steps and cluster count
- ExportDialogView: Sheet for selecting export format and destination
- SettingsView: Form-based preferences (export defaults, CloudKit toggle, minimum artifact threshold)
- **Interfaces:**
- SidebarViewModel: @Observable class with phases: [AestheticPhase], selectedPhase: AestheticPhase?, timelinePosition: Double
- GalleryViewModel: @Observable class with artifacts: [CreativeArtifact], selectedArtifact: CreativeArtifact?, sortOrder: SortOrder
- EvolutionViewModel: @Observable class with currentPhase: AestheticPhase?, projection: StyleProjection?, refinementOffset: CGSize
- ImportViewModel: @Observable class with importProgress: ImportProgress?, isImporting: Bool, func startImport(urls: [URL])
- ExportViewModel: @Observable class with selectedFormat: ExportFormat, func exportProjection(_ projection: StyleProjection)
- **Dependencies:**
- DomainServices
- DataLayer

### DomainServices
- **Responsibilities:**
- Coordinate all domain logic between presentation and data/ML layers
- ArtifactImportService: File validation, thumbnail generation, bulk import orchestration
- StyleVectorExtractor: Core ML model lifecycle, single and batch vector extraction
- EvolutionEngine: K-means clustering, elbow method, chronological phase ordering, trajectory computation
- ProjectionGenerator: Forward projection from trajectory, palette generation, layout grid generation, confidence scoring
- ExportService: Multi-format encoding and file writing for palettes and layouts
- **Interfaces:**
- ArtifactImportService: @Observable final class, Sendable
- StyleVectorExtractor: final class with nonisolated methods, Sendable
- EvolutionEngine: final class, Sendable
- ProjectionGenerator: final class, Sendable
- ExportService: final class, Sendable
- **Dependencies:**
- CoreMLLayer
- DataLayer

### CoreMLLayer
- **Responsibilities:**
- Load and manage StyleFeatureExtractor.mlmodelc Core ML model
- Perform inference to extract 33-dimensional style vectors from CGImage input
- Handle ANE/GPU delegation automatically via Core ML runtime
- Provide synchronous prediction wrapped in async interface for structured concurrency
- Color quantization using k-means on pixel data for dominant palette extraction
- **Interfaces:**
- StyleFeatureModel: final class wrapping MLModel with func predict(image: CGImage) throws -> MLFeatureProvider
- ColorQuantizer: struct with static func dominantColors(from image: CGImage, count: Int = 5) -> [SIMD4<Float>]

### DataLayer
- **Responsibilities:**
- SwiftData model definitions: CreativeArtifact, AestheticPhase, StyleProjection, UserPreferences
- ModelContainer factory with schema versioning via VersionedSchema
- SchemaMigrationPlan for V1 -> future versions
- CloudKit sync configuration (optional, toggled via UserPreferences)
- StyleVector Codable encoding/decoding with format versioning
- **Interfaces:**
- CreativeArtifact: @Model final class
- AestheticPhase: @Model final class
- StyleProjection: @Model final class
- UserPreferences: @Model final class
- StyleVector: Codable, Sendable struct
- SchemaV1: VersionedSchema
- StylePhantomMigrationPlan: SchemaMigrationPlan

### MetalShaders
- **Responsibilities:**
- Timeline gradient shader: Renders phase color bands with smooth blending for the evolution timeline scrubber
- Style vector heatmap shader: Visualizes vector dimensions as a radial heatmap overlay on artifacts in the evolution viewer
- Transition shader: Custom wipe/morph transition used in side-by-side evolution comparison drag-to-refine
- **Interfaces:**
- ShaderLibrary.timelineGradient: (float, float, [float4]) -> color
- ShaderLibrary.vectorHeatmap: (float2, [float]) -> color
- ShaderLibrary.evolutionTransition: (float2, float, color, color) -> color

## 🗃 Data Model Notes
- CreativeArtifact @Model: id (UUID, unique), imageBookmarkData (Data, security-scoped bookmark to original file), thumbnailData (Data, JPEG-compressed CGImage at 512px max dimension), importDate (Date), manualTags ([String]), styleVectorData (Data?, encoded StyleVector with format version prefix byte), styleVectorVersion (Int, defaults to 1, incremented when vector format changes), phase (AestheticPhase?, @Relationship inverse: \.artifacts)

- AestheticPhase @Model: id (UUID, unique), label (String, auto-generated like 'Minimalist Phase' or user-editable), centroidVectorData (Data, encoded StyleVector), dateRangeStart (Date), dateRangeEnd (Date), artifacts ([CreativeArtifact], @Relationship deleteRule: .nullify inverse: \.phase), projections ([StyleProjection], @Relationship deleteRule: .cascade inverse: \.sourcePhase)

- StyleProjection @Model: id (UUID, unique), projectedVectorData (Data, encoded StyleVector), paletteJSON (Data, encoded [PaletteColor]), layoutJSON (Data, encoded LayoutGrid), structuralNotes (String), confidence (Double, 0.0-1.0), creationDate (Date), sourcePhase (AestheticPhase?, @Relationship inverse: \.projections)

- UserPreferences @Model: id (UUID, unique, singleton pattern — fetch first or create), defaultPaletteExportFormat (String, raw value of PaletteExportFormat), defaultLayoutExportFormat (String, raw value of LayoutExportFormat), cloudKitSyncEnabled (Bool, default false), minimumArtifactThreshold (Int, default 5), preferredClusterCount (Int?, nil means auto-detect via elbow method)

- StyleVector (plain struct, not @Model): colorPalette ([SIMD4<Float>], 5 entries), composition (SIMD8<Float>), texture (SIMD4<Float>), complexity (Float). Conforms to Codable and Sendable. Encoded with a 1-byte version prefix followed by JSON payload. Total: 33 floating-point dimensions.

- PaletteColor (plain struct): hex (String, '#RRGGBB'), name (String, generated descriptive name), rgba (SIMD4<Float>). Codable, Sendable.

- LayoutGrid (plain struct): columns (Int), rows (Int), gutterWidth (Float), marginWidth (Float), aspectRatios ([Float], per-cell suggested ratios). Codable, Sendable.

- All Data blob fields use a version-prefix encoding strategy: first byte is format version (UInt8), remaining bytes are the JSON-encoded payload. This allows future vector dimension changes without a full SwiftData migration — the decoder reads the version byte and uses the matching decoder.

## 🔐 Validation & Security
- Image import validates file type against UTType conforming to .image (JPEG, PNG, TIFF, HEIC, WebP). Rejects files over 100MB.
- Security-scoped bookmarks used for imageBookmarkData to maintain sandbox-safe file access across app launches. Bookmark resolution checked on each access with fallback to thumbnail.
- Style vector encoding uses a version byte prefix. If the decoder encounters an unknown version, it returns nil and flags the artifact for re-extraction rather than crashing.
- CloudKit sync restricts all data to the user's CKContainer.default() private database. No public or shared databases used. No PII beyond the user's own creative artifacts.
- NSSavePanel/NSOpenPanel used for all file system access. No hardcoded paths. App Sandbox enabled with com.apple.security.files.user-selected.read-write entitlement.
- Core ML model is embedded in the app bundle. No model downloads from network. Model hash verified at build time via Xcode resource validation.
- Export file formats (ASE, JSON, CSS, SVG) are generated from sanitized internal data structures. No user-supplied strings are interpolated into file output without escaping.
- UserPreferences singleton enforced by always fetching with FetchDescriptor limited to 1 result, creating only if empty.

## 🧯 Error Handling Strategy
All service methods throw typed errors defined per service (ImportError, ExtractionError, EvolutionError, ProjectionError, ExportError). View models catch these errors and expose them as optional alert state (@Observable var currentError: AppError?). Presentation layer displays errors via .alert modifier bound to the view model error state. No silent error swallowing — every catch block either surfaces the error to the user or logs it and retries. AsyncThrowingStream-based APIs (import, batch extraction) yield partial results before throwing, so the UI shows progress up to the failure point. Core ML model loading failures at app launch show a non-dismissable alert with instructions to reinstall. All errors conform to LocalizedError for user-facing descriptions.

## 🔭 Observability
- **Logging:** Swift os.Logger with subsystem 'com.stylephantom.app' and per-module categories: 'import', 'extraction', 'evolution', 'projection', 'export', 'sync'. Log levels: .debug for timing/perf metrics, .info for operation start/complete, .error for failures with attached error descriptions. Logs visible in Console.app with subsystem filter. No log data leaves the device.
- **Tracing:** Structured Concurrency task hierarchy provides implicit trace context. os.Signpost used for Instruments integration: signpost intervals around Core ML inference, K-means clustering, and export encoding. Instruments Time Profiler and Core ML Instruments template used for performance analysis during development. No distributed tracing needed (local-only app).
- **Metrics:**
- Import throughput: artifacts per second, logged at .debug level after each batch import
- Extraction latency: milliseconds per artifact for Core ML inference, logged at .debug
- Clustering duration: total seconds for K-means computation, logged at .info
- Projection confidence distribution: histogram of confidence scores across generated projections, logged at .debug
- Memory footprint: peak resident memory during batch operations, sampled via ProcessInfo and logged at .debug
- UI frame rate: TimelineView callback frequency logged during timeline scrubbing to verify 60fps target

## ⚡ Performance Notes
- Core ML inference dispatched to background TaskGroup with concurrency capped at ProcessInfo.processInfo.activeProcessorCount to saturate cores without oversubscription. CGImage passed by reference, not copied.
- K-means clustering operates on in-memory [StyleVector] arrays. For 500 artifacts x 33 dimensions, working set is ~66KB — fits in L1 cache on Apple Silicon. Max iterations capped at 100 with early termination on convergence (centroid movement < 1e-6).
- Artifact gallery uses LazyVGrid with thumbnail Data decoded to CGImage on demand via a @Observable thumbnail cache limited to 200 entries (LRU eviction). Thumbnails are JPEG at ~50KB each.
- Timeline scrubber uses TimelineView with .animation schedule and Metal shader rendering. Phase color data passed as a uniform buffer, not per-frame recomputed. GPU handles interpolation.
- Side-by-side evolution viewer uses matchedGeometryEffect for namespace-scoped transitions. Drag-to-refine modifies a CGSize offset that linearly interpolates between current and projected style vectors — no re-clustering on drag, only palette/layout regeneration from the interpolated vector.
- SwiftData @Query used for artifact browsing with SortDescriptor on importDate. FetchDescriptor with fetchLimit used for paginated loading in large libraries. No @Query in tight loops.
- CloudKit sync runs on a background ModelContext. CKSyncEngine (if available on macOS 15) or manual CKModifyRecordsOperation batched at 400 records. Sync never blocks the main ModelContext.
- Image bookmark resolution is lazy — only resolved when the user requests the full-resolution original from the detail view, not during gallery browsing.

## 🧪 Testing Strategy
### Unit
- StyleVector encoding/decoding: Verify round-trip through version-prefixed Data encoding. Test unknown version byte returns nil gracefully.
- ColorQuantizer: Feed known-color images (solid red, gradient) and assert dominant colors match expected SIMD4<Float> values within tolerance.
- EvolutionEngine.kMeans: Test with synthetic 2D vectors where cluster membership is deterministic. Verify cluster count, centroid positions, and member assignment.
- EvolutionEngine.elbowMethod: Test with datasets of known optimal k (e.g., 3 well-separated Gaussian blobs) and verify selected k matches.
- EvolutionEngine.computeTrajectory: Feed 3 ordered phases with linearly increasing centroids. Assert velocity is constant and acceleration is near-zero.
- ProjectionGenerator: Feed a known trajectory (linear) and verify projected vector extends the line. Verify confidence decays per step.
- PaletteColor hex generation: Verify SIMD4<Float> to hex string conversion for edge cases (0.0, 1.0, midpoints).
- LayoutGrid generation: Verify grid parameters are within sane bounds (columns 1-12, rows 1-6, non-negative gutters).
- ExportService ASE encoding: Verify output bytes match Adobe Swatch Exchange binary format spec for known palettes.
- UserPreferences singleton enforcement: Insert two, fetch with limit 1, verify only one returned.
### Integration
- Full import pipeline: Drop a test image set (5 PNGs) through ArtifactImportService, verify CreativeArtifact records created in SwiftData with thumbnails and nil style vectors.
- Import + Extraction pipeline: Import test images, run StyleVectorExtractor.batchExtract, verify all artifacts have non-nil styleVectorData with correct version byte.
- Full evolution pipeline: Import 20 test images with known creation dates, extract vectors, run EvolutionEngine.computePhases, verify phases are chronologically ordered and all artifacts assigned.
- Evolution + Projection pipeline: After computing phases, run ProjectionGenerator, verify StyleProjection records created with non-empty palette and layout JSON.
- Export pipeline: Generate a projection, export as each format (ASE, JSON, CSS, SVG), verify files are non-empty and parseable.
- SwiftData ModelContainer lifecycle: Create container, insert artifacts, delete phase (verify cascade deletes projections but nullifies artifact.phase), verify ModelContext save succeeds.
### E2E
- Full user journey: Launch app -> import 10 test images via ImportSheetView -> wait for extraction -> navigate to timeline -> select phase -> view projection -> export palette as JSON -> verify file contents.
- Empty state: Launch app with no artifacts -> verify empty state messaging in gallery and sidebar -> import single image -> verify it appears in gallery.
- Large library: Import 500 synthetic test images -> verify evolution computation completes within 3s -> verify timeline scrubbing maintains 60fps (measured via CADisplayLink callback frequency).
- Settings persistence: Change export format in SettingsView -> quit and relaunch -> verify setting persists.
- Drag-to-refine: Navigate to evolution viewer -> drag between current and projected -> verify palette interpolation updates in real-time without lag.

## 🚀 Rollout Plan
- Phase 1 — Data Foundation (Week 1-2): Implement DataLayer module: all SwiftData @Model definitions, StyleVector Codable struct, schema versioning, ModelContainer factory. Write unit tests for encoding/decoding. Set up Xcode project with Swift 6 language mode, create folder structure for all modules.

- Phase 2 — Import Pipeline (Week 2-3): Implement ArtifactImportService with file validation, thumbnail generation (vImage), security-scoped bookmark storage, and bulk import AsyncThrowingStream. Build ImportSheetView with drag-and-drop and progress bar. Integration test full import flow.

- Phase 3 — Core ML Integration (Week 3-4): Train or source StyleFeatureExtractor Core ML model (MobileNetV3 fine-tuned for style features, or use Apple's built-in feature extractor with post-processing). Implement StyleVectorExtractor with single and batch extraction. Implement ColorQuantizer. Unit test against known images.

- Phase 4 — Evolution Engine (Week 4-5): Implement K-means clustering with elbow method, chronological phase ordering, and trajectory computation. Build AestheticPhase persistence. Unit test clustering correctness. Integration test with real extracted vectors.

- Phase 5 — Projection & Gallery UI (Week 5-6): Implement ProjectionGenerator for palette, layout, and structural recommendations. Build NavigationSplitView shell, SidebarView with phase list, ArtifactGalleryView with LazyVGrid and matchedGeometryEffect transitions. Connect view models to services.

- Phase 6 — Evolution Viewer & Timeline (Week 6-7): Build side-by-side EvolutionViewerView with drag-to-refine. Implement TimelineScrubberView with TimelineView and Metal shaders. Verify 60fps performance. PhaseAnimator for style evolution animations.

- Phase 7 — Export & Settings (Week 7-8): Implement ExportService with all formats (ASE, JSON, CSS, SVG, Figma tokens). Build ExportDialogView and SettingsView. Implement UserPreferences singleton. NSWindow vibrancy customization for premium feel. MenuBarExtra for quick import.

- Phase 8 — CloudKit Sync (Week 8-9): Implement optional CloudKit sync on UserPreferences toggle. Background ModelContext for sync operations. Last-writer-wins conflict resolution on style vectors. Test multi-Mac round-trip.

- Phase 9 — Polish & Performance (Week 9-10): Profile with Instruments (Time Profiler, Core ML template, Metal System Trace). Optimize any frame drops in timeline scrubber. Verify all NFRs: 2s launch, 500ms extraction, 3s evolution for 500 artifacts. Full e2e test suite. Accessibility audit (VoiceOver, Dynamic Type in settings).

- Phase 10 — Distribution (Week 10-11): Xcode Cloud CI pipeline. TestFlight beta. Mac App Store submission or notarized DMG. Landing page with feature overview.

## ❓ Open Questions
- Core ML model sourcing: Should we fine-tune MobileNetV3 on a style-annotated dataset, use Apple's Vision framework VNFeaturePrintObservation as the base vector and add post-processing, or train a custom model from scratch? VNFeaturePrintObservation gives a 2048-dim vector that could be PCA-reduced to 33 dimensions with minimal quality loss.
- Cluster count UX: Should the elbow method run automatically and show the user the recommended k, or should users manually set cluster count via a slider? Auto-detection is simpler but may produce unintuitive phase boundaries for some collections.
- Style vector versioning migration: When the Core ML model changes and vector dimensionality shifts, should existing artifacts be automatically re-extracted in a background pass, or should users trigger re-extraction manually? Automatic is better UX but could be CPU-intensive for large libraries.
- CloudKit record size: StyleVector encoded data is small (~2KB), but thumbnailData at 512px JPEG could be 30-80KB. CloudKit CKAsset has a 50MB limit per asset which is fine, but total private database quota is 1GB free tier. Should we sync thumbnails or regenerate them on each Mac from the original file (requires iCloud Drive access to originals)?
- Export format priorities: The ARD lists ASE, JSON, CSS, SVG, and Figma tokens. Should all be in v1, or should we ship with JSON + CSS and add others based on user demand? Each format adds testing surface.
- Drag-to-refine interpolation: Linear interpolation between current and projected vectors is the simplest approach. Should we offer cubic or spline interpolation for smoother exploration, or is linear sufficient for v1?