# Agent Prompts — StylePhantom

## Global Rules

### Do
- Use Swift 6 strict concurrency throughout; all types must be Sendable where required
- Use @Observable (Observation framework) for all ViewModels, never ObservableObject
- Use SwiftData with VersionedSchema and SchemaMigrationPlan from day one
- Use structured concurrency (async/await, TaskGroup) for all async work; no Combine
- Target macOS 15+ Sequoia only; use SwiftUI 6 APIs (PhaseAnimator, TimelineView, ShaderLibrary)

### Don't
- Do not use ObservableObject, @Published, or Combine — use @Observable exclusively
- Do not add any server, network dependency, or third-party packages for core features
- Do not use UIKit or AppKit views unless wrapping NSWindow customization specifically
- Do not create a custom Metal rendering pipeline — use ShaderLibrary from SwiftUI only
- Do not use Core Data — SwiftData is the only persistence layer

---

## Task Prompts
### Task 1: Project Scaffold, SwiftData Models & Persistence Layer

**Role:** Expert Swift 6 / SwiftData Engineer
**Goal:** Create project scaffold with all SwiftData models, schemas, and persistence tests

**Context**
Set up the Xcode project structure, define all SwiftData models with relationships, create the ModelContainer factory, and write unit tests for persistence round-trips. This is the foundation everything else builds on.

**Files to Create**
- StylePhantom/Models/StyleVector.swift
- StylePhantom/Models/PaletteColor.swift
- StylePhantom/Models/LayoutGrid.swift
- StylePhantom/Models/CreativeArtifact.swift
- StylePhantom/Models/AestheticPhase.swift
- StylePhantom/Models/StyleProjection.swift
- StylePhantom/Models/UserPreferences.swift
- StylePhantom/Models/SchemaV1.swift

**Files to Modify**
- StylePhantom/StylePhantomApp.swift

**Steps**
1. Create StyleVector struct (Codable, Sendable) with colorPalette [SIMD4<Float>] (5 entries), composition SIMD8<Float>, texture SIMD4<Float>, complexity Float. Add version-prefixed encode/decode (UInt8 version byte 1 + JSON). Create PaletteColor (hex String, name String, rgba SIMD4<Float>) and LayoutGrid (columns Int, rows Int, gutterWidth Float, marginWidth Float, aspectRatios [Float]), both Codable+Sendable.
2. Create CreativeArtifact @Model with id UUID, imageBookmarkData Data, thumbnailData Data, importDate Date, manualTags [String], styleVectorData Data?, styleVectorVersion Int (default 1), phase AestheticPhase? (@Relationship inverse). Add computed styleVector property. Create AestheticPhase @Model with id UUID, label String, centroidVectorData Data, dateRangeStart/End Date, artifacts [CreativeArtifact] (@Relationship deleteRule .nullify), projections [StyleProjection] (@Relationship deleteRule .cascade).
3. Create StyleProjection @Model with id UUID, projectedVectorData Data, paletteJSON Data, layoutJSON Data, structuralNotes String, confidence Double, creationDate Date, sourcePhase AestheticPhase? (@Relationship inverse). Add computed properties for decoded palette and layout. Create UserPreferences @Model with singleton pattern via static func shared(in:).
4. Create SchemaV1 VersionedSchema listing all four models, StylePhantomMigrationPlan with empty stages, and ModelContainerFactory with static func create(inMemory: Bool = false) throws -> ModelContainer. Wire into StylePhantomApp with .modelContainer modifier. Add App Sandbox entitlement.
5. Write unit tests: StyleVector round-trip encode/decode, unknown version returns nil, empty data returns nil, SIMD precision preserved. SwiftData relationship tests: delete phase nullifies artifact.phase, delete phase cascades projections, UserPreferences singleton behavior. All tests use in-memory ModelContainer.

**Validation**
`xcodebuild test -scheme StylePhantom -destination 'platform=macOS' -only-testing StylePhantomTests/ModelTests 2>&1 | tail -20`

---

### Task 2: Import Pipeline & Core ML Style Extraction

**Role:** Expert Swift 6 / CoreML / Vision Framework Engineer
**Goal:** Build import pipeline with thumbnails and Core ML style vector extraction

**Context**
Build the artifact import service (drag-drop, file picker, thumbnails, bookmarks) and the Core ML style vector extraction pipeline. These two systems together populate CreativeArtifact records with image data and 33-dim style vectors.

**Files to Create**
- StylePhantom/Services/ArtifactImportService.swift
- StylePhantom/Services/StyleVectorExtractor.swift
- StylePhantom/CoreML/ColorQuantizer.swift
- StylePhantom/ViewModels/ImportViewModel.swift
- StylePhantom/Views/ImportSheetView.swift

**Files to Modify**
_None_

**Steps**
1. Create ArtifactImportService (@Observable, Sendable) with validateFile(url:) checking UTType conforms to .image and size <= 100MB, generateThumbnail(for:maxDimension:512) using CGImageSource+vImage scaling to JPEG Data, createBookmark/resolveBookmark using security-scoped bookmarks, and importArtifacts(from:into:) returning AsyncThrowingStream<ImportProgress, Error> with duplicate detection by bookmark hash.
2. Create ColorQuantizer with static func dominantColors(from:count:5) -> [SIMD4<Float>] using pixel sampling + k-means on RGB, returning centroids sorted by cluster size. Target < 50ms for 512x512.
3. Create StyleVectorExtractor (final class, Sendable) with extractVector(from:) using VNFeaturePrintObservation for 2048-dim features, PCA reduction to 33 dims (hardcoded matrix), combined with ColorQuantizer output for colorPalette. Add batchExtract(from:context:concurrency:4) using bounded TaskGroup, updating artifact.styleVectorData in-place.
4. Create ImportViewModel (@Observable) with importProgress, isImporting, errorMessage, startImport(urls:), cancelImport(). Create ImportSheetView with drop zone (.image UTTypes), Browse Files button (NSOpenPanel), progress bar, cancel button.
5. Write tests: ColorQuantizer with solid red image, 50/50 split, gradient. Integration test: import 5 PNGs -> extract vectors -> verify all artifacts have styleVectorData with version byte 1. All tests use in-memory ModelContainer.

**Validation**
`xcodebuild test -scheme StylePhantom -destination 'platform=macOS' -only-testing StylePhantomTests/ImportTests -only-testing StylePhantomTests/ExtractionTests 2>&1 | tail -20`

---

### Task 3: Evolution Engine & Projection Generator

**Role:** Expert Swift 6 / ML Algorithm Engineer
**Goal:** Build evolution clustering, trajectory computation, and forward projection generator

**Context**
Implement k-means clustering to group artifacts into aesthetic phases, compute style trajectory (velocity/acceleration), and project future styles with palette/layout/structural recommendations. This is the core intelligence of the app.

**Files to Create**
- StylePhantom/Services/EvolutionEngine.swift
- StylePhantom/Services/ProjectionGenerator.swift

**Files to Modify**
_None_

**Steps**
1. Create EvolutionEngine (final class, Sendable) with private kMeans(vectors:k:maxIterations:100, tolerance:1e-6) returning (centroids, assignments), and elbowMethod(vectors:kRange:2...10) selecting k via maximum second derivative of WCSS curve.
2. Add computePhases(from:clusterCount:) -> [AestheticPhase] that extracts/flattens style vectors, runs k-means (elbow if clusterCount nil), creates AestheticPhase records sorted chronologically by dateRangeStart, assigns artifacts. Throws insufficientArtifacts (< 5) or missingStyleVectors. Add computeTrajectory(from:) -> StyleTrajectory with velocity (avg diff between consecutive centroids) and acceleration (second derivative).
3. Create ProjectionGenerator (final class, Sendable) with generateProjection(from:steps:1) extrapolating via velocity*step + 0.5*acceleration*step^2, clamping to [0,1], confidence = max(0.1, 1.0 - 0.2*step). Add palette generation (RGBA->hex, HSL hue->descriptive names), layout grid mapping (symmetry->columns, balance->rows, negative-space->gutter), and structural notes (threshold-based compositional advice).
4. Wire ProjectionGenerator to persist StyleProjection @Model instances with encoded paletteJSON, layoutJSON, structuralNotes, confidence, sourcePhase relationship into ModelContext.
5. Write unit tests: k-means with 3 Gaussian blobs, elbow method with known-k data, linear trajectory produces constant velocity/zero acceleration, projection math at steps 1-5, confidence decay, hex conversion (#FF0000), layout bounds for extreme inputs. Integration test: 20 artifacts -> computePhases -> computeTrajectory -> generateProjection succeeds.

**Validation**
`xcodebuild test -scheme StylePhantom -destination 'platform=macOS' -only-testing StylePhantomTests/EvolutionTests -only-testing StylePhantomTests/ProjectionTests 2>&1 | tail -20`

---

### Task 4: UI Shell, Evolution Viewer, Timeline & Metal Shaders

**Role:** Expert SwiftUI 6 / Metal Shader Engineer
**Goal:** Build full UI with gallery, evolution viewer, Metal timeline, and settings

**Context**
Build the complete UI: NavigationSplitView with sidebar/gallery/detail, evolution viewer with drag-to-refine, Metal-powered timeline scrubber, settings, and menu bar extra. This is all the visual and interactive layer.

**Files to Create**
- StylePhantom/Views/ContentView.swift
- StylePhantom/Views/ArtifactGalleryView.swift
- StylePhantom/Views/ArtifactDetailView.swift
- StylePhantom/Views/EvolutionViewerView.swift
- StylePhantom/Views/TimelineScrubberView.swift
- StylePhantom/Views/SettingsView.swift
- StylePhantom/ViewModels/SidebarViewModel.swift
- StylePhantom/Metal/TimelineShaders.metal

**Files to Modify**
- StylePhantom/StylePhantomApp.swift

**Steps**
1. Build ContentView with NavigationSplitView (three-column): sidebar listing AestheticPhase entries (@Query) with labels/date ranges, content column with ArtifactGalleryView (LazyVGrid, adaptive columns min 120pt, thumbnails from Data, @Query sorted by importDate), detail column with ArtifactDetailView (matchedGeometryEffect transition, metadata display, 'Extract Style' button). Create SidebarViewModel and GalleryViewModel (@Observable). Add LRU ThumbnailCache (200 entries, background decode).
2. Build EvolutionViewerView with HStack: current phase (PaletteSwatchView + LayoutGridPreview) on left, projected phase on right. Add DragGesture for drag-to-refine: interpolation factor t = clamp(drag.x / viewWidth, 0, 1), linear interpolation of StyleVector dims, real-time palette/layout update. Create EvolutionViewModel (@Observable). Add PhaseAnimator for phase transition animations with spring timing.
3. Write Metal shaders in TimelineShaders.metal: timelineGradient (horizontal phase color bands with smoothstep blending), vectorHeatmap (radial heatmap, cool-to-warm color mapping), evolutionTransition (wipe effect controlled by float t). Build TimelineScrubberView using TimelineView(.animation), render via ShaderLibrary, draggable scrubber handle updating SidebarViewModel.timelinePosition.
4. Build SettingsView (Settings scene) with Form: Export Defaults pickers, Evolution params (artifact threshold stepper, cluster count), CloudKit sync toggle with confirmation alert. Build ProjectionConfigSheet (steps 1-5 stepper, auto/manual cluster count). Add NSApplicationDelegateAdaptor for NSWindow customization (.ultraThinMaterial sidebar, .titlebarAppearsTransparent, min size 900x600). Add MenuBarExtra with Import/Recompute items.
5. Create ViewModels/EvolutionViewModel.swift (@Observable) with currentPhase, projection, refinementOffset, interpolatedPalette, interpolatedLayout. Create ViewModels/GalleryViewModel.swift (@Observable) with artifacts, selectedArtifact, sortOrder. Wire all views together in StylePhantomApp with .modelContainer, Settings scene, and MenuBarExtra scene.

**Validation**
`xcodebuild build -scheme StylePhantom -destination 'platform=macOS' 2>&1 | tail -20`

---

### Task 5: Export System, CloudKit Sync, Logging & E2E Tests

**Role:** Expert Swift 6 / CloudKit / Testing Engineer
**Goal:** Build exports, CloudKit sync, observability, and E2E test suite

**Context**
Build the multi-format export system (ASE, JSON, CSS, SVG, Figma tokens), optional CloudKit sync with conflict resolution, structured logging with Instruments signposts, and comprehensive E2E/performance tests.

**Files to Create**
- StylePhantom/Services/ExportService.swift
- StylePhantom/Views/ExportDialogView.swift
- StylePhantom/ViewModels/ExportViewModel.swift
- StylePhantom/Services/Logging.swift

**Files to Modify**
- StylePhantom/Models/ModelContainerFactory.swift
- StylePhantom/Models/CreativeArtifact.swift

**Steps**
1. Create ExportService (final class, Sendable) with exportPalette(_:format:to:) supporting .json (array of {hex,name,rgba}), .css (:root custom properties), .ase (ASEF magic bytes 0x41534546, version 1.0, UTF-16 names, RGB floats). Add exportLayout(_:format:to:) supporting .json (design-token format), .svg (grid lines with <line>/<text> annotations), .figmaTokens (Figma tokens plugin JSON). Build ExportDialogView with format pickers, preview, NSSavePanel. Create ExportViewModel (@Observable).
2. Modify ModelContainerFactory to accept cloudKitEnabled parameter using CKContainer.default() private database. Add syncTimestamp field to CreativeArtifact. Implement conflict resolution: last-writer-wins on styleVectorData by syncTimestamp. Handle CKError cases: .quotaExceeded (alert), .networkUnavailable (queue retry), .serverRecordChanged (conflict resolution). Toggle in Settings with confirmation alert, container recreation on toggle.
3. Create Logging.swift with static Logger instances for 6 categories (import, extraction, evolution, projection, export, sync) under subsystem 'com.stylephantom.app'. Add os.Signpost intervals around Core ML inference, k-means clustering, export encoding, thumbnail generation. Log performance metrics at .debug: import throughput, extraction latency, clustering duration, memory sampling.
4. Write E2E UI tests: full journey (launch -> import 10 images -> extraction -> timeline -> select phase -> evolution viewer -> export JSON -> verify file contents). Empty state test (no artifacts -> import 1 -> verify gallery, sidebar threshold warning). Drag-to-refine test (simulate drag -> verify palette interpolation). Performance test: 500 synthetic artifacts, evolution < 3s, timeline 60fps, memory < 500MB.
5. Write unit tests for ASE binary encoding (magic bytes, color count, float precision). Integration test for all 5 export formats (non-empty, parseable). Accessibility audit: add accessibilityLabel to palette swatches, thumbnails, timeline controls; accessibilityHint for drag-to-refine; verify Dynamic Type in SettingsView. Profile with Instruments and document findings.

**Validation**
`xcodebuild test -scheme StylePhantom -destination 'platform=macOS' 2>&1 | tail -20`