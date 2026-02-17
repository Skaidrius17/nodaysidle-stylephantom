# Tasks Plan — Style Phantom

## 📌 Global Assumptions
- Solo developer working on macOS 15+ Sequoia with Xcode 16+ and Swift 6
- Core ML style extraction will use VNFeaturePrintObservation with PCA reduction to 33 dimensions rather than a custom-trained model for v1
- All processing is on-device with no server or network dependency for core features
- CloudKit sync is optional and deferred to later phase; core app works fully offline
- Test images for integration and E2E tests are generated synthetically or bundled as test resources
- Metal shader development uses ShaderLibrary from SwiftUI, not a separate Metal rendering pipeline
- All export formats ship in v1 as specified in the TRD

## ⚠️ Risks
- VNFeaturePrintObservation 2048-dim to 33-dim PCA reduction may lose meaningful style signal — mitigation: validate with diverse test images early in Phase 3
- K-means clustering on subjective style vectors may produce unintuitive phase boundaries — mitigation: allow manual cluster count override and phase label editing
- Metal shader development for timeline and heatmap may require significant iteration for visual polish — mitigation: start with simple color fills, iterate visually
- CloudKit sync of thumbnail data may hit 1GB free tier quota for users with large libraries — mitigation: sync only metadata, regenerate thumbnails locally
- ASE binary format encoding is error-prone without a reference implementation — mitigation: validate against Adobe tool import early
- Large library performance (500+ artifacts) for batch Core ML inference may be slow on older Apple Silicon — mitigation: bounded TaskGroup concurrency, progress indication

## 🧩 Epics
## Project Scaffolding & Data Foundation
**Goal:** Set up the Xcode project with Swift 6 strict concurrency, define all SwiftData models, and verify persistence round-trips

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create Xcode project with Swift 6 language mode (2h)

Create a new macOS App project targeting macOS 15+ Sequoia. Enable Swift 6 strict concurrency. Set up folder structure: App/, Views/, ViewModels/, Services/, Models/, CoreML/, Metal/, Tests/. Add App Sandbox entitlement with com.apple.security.files.user-selected.read-write.

**Acceptance Criteria**
- Project builds with zero warnings under Swift 6 strict concurrency
- Folder structure matches module layout from TRD
- App Sandbox entitlement configured correctly
- App launches to an empty window

**Dependencies**
_None_

### ✅ Define StyleVector Codable struct with version-prefixed encoding (2h)

Create Models/StyleVector.swift. Implement StyleVector struct with colorPalette ([SIMD4<Float>], 5 entries), composition (SIMD8<Float>), texture (SIMD4<Float>), complexity (Float). Conform to Codable and Sendable. Implement encode(to data: Data) that prepends a UInt8 version byte (1) followed by JSON payload. Implement static decode(from data: Data) -> StyleVector? that reads version byte and decodes accordingly, returning nil for unknown versions.

**Acceptance Criteria**
- Round-trip encode/decode preserves all 33 float values exactly
- Unknown version byte returns nil without crashing
- Empty data returns nil without crashing
- Struct conforms to Sendable

**Dependencies**
_None_

### ✅ Define PaletteColor and LayoutGrid value types (1h)

Create Models/PaletteColor.swift with hex (String), name (String), rgba (SIMD4<Float>). Create Models/LayoutGrid.swift with columns (Int), rows (Int), gutterWidth (Float), marginWidth (Float), aspectRatios ([Float]). Both Codable and Sendable.

**Acceptance Criteria**
- PaletteColor round-trips through JSON encode/decode
- LayoutGrid round-trips through JSON encode/decode
- Both conform to Sendable

**Dependencies**
_None_

### ✅ Define CreativeArtifact SwiftData model (2h)

Create Models/CreativeArtifact.swift. @Model final class with: id (UUID), imageBookmarkData (Data), thumbnailData (Data), importDate (Date), manualTags ([String]), styleVectorData (Data?), styleVectorVersion (Int, default 1), phase (AestheticPhase?, @Relationship inverse). Add computed property to decode styleVectorData into StyleVector?.

**Acceptance Criteria**
- Model compiles under Swift 6 strict concurrency
- Relationship to AestheticPhase declared with inverse
- styleVector computed property decodes/returns nil correctly
- Can insert and fetch from an in-memory ModelContainer in a test

**Dependencies**
- Define StyleVector Codable struct with version-prefixed encoding

### ✅ Define AestheticPhase SwiftData model (2h)

Create Models/AestheticPhase.swift. @Model final class with: id (UUID), label (String), centroidVectorData (Data), dateRangeStart (Date), dateRangeEnd (Date), artifacts ([CreativeArtifact], @Relationship deleteRule .nullify), projections ([StyleProjection], @Relationship deleteRule .cascade). Add computed centroidVector property.

**Acceptance Criteria**
- Deleting a phase nullifies artifact.phase but does not delete artifacts
- Deleting a phase cascades to delete its projections
- centroidVector computed property decodes correctly

**Dependencies**
- Define CreativeArtifact SwiftData model

### ✅ Define StyleProjection SwiftData model (1.5h)

Create Models/StyleProjection.swift. @Model final class with: id (UUID), projectedVectorData (Data), paletteJSON (Data), layoutJSON (Data), structuralNotes (String), confidence (Double), creationDate (Date), sourcePhase (AestheticPhase?, @Relationship inverse). Add computed properties for decoded palette and layout.

**Acceptance Criteria**
- paletteJSON decodes to [PaletteColor] via computed property
- layoutJSON decodes to LayoutGrid via computed property
- Relationship inverse to AestheticPhase.projections works

**Dependencies**
- Define AestheticPhase SwiftData model
- Define PaletteColor and LayoutGrid value types

### ✅ Define UserPreferences SwiftData model with singleton pattern (1.5h)

Create Models/UserPreferences.swift. @Model final class with: id (UUID), defaultPaletteExportFormat (String), defaultLayoutExportFormat (String), cloudKitSyncEnabled (Bool, default false), minimumArtifactThreshold (Int, default 5), preferredClusterCount (Int?). Add static func shared(in context: ModelContext) -> UserPreferences that fetches with limit 1 or creates default.

**Acceptance Criteria**
- Calling shared() twice returns the same instance
- Inserting two preferences and calling shared() returns only one
- Default values are correct on fresh creation

**Dependencies**
_None_

### ✅ Create ModelContainer factory with VersionedSchema (2h)

Create Models/SchemaV1.swift with VersionedSchema listing all four models. Create Models/StylePhantomMigrationPlan.swift with SchemaMigrationPlan (stages empty for v1). Create Models/ModelContainerFactory.swift with static func create(inMemory: Bool = false) throws -> ModelContainer. Wire into App entry point.

**Acceptance Criteria**
- ModelContainer creates successfully with all four model types
- inMemory mode works for tests
- Schema version is set to V1
- App launches without SwiftData errors

**Dependencies**
- Define CreativeArtifact SwiftData model
- Define AestheticPhase SwiftData model
- Define StyleProjection SwiftData model
- Define UserPreferences SwiftData model with singleton pattern

### ✅ Write unit tests for StyleVector encoding/decoding (1.5h)

Create tests for: round-trip encode/decode with known values, unknown version byte returns nil, empty data returns nil, corrupted JSON returns nil, SIMD component precision preserved.

**Acceptance Criteria**
- All five test cases pass
- Tests run in under 1 second
- No test uses network or file system

**Dependencies**
- Define StyleVector Codable struct with version-prefixed encoding

### ✅ Write unit tests for SwiftData model relationships and cascades (2h)

Test: insert artifact into phase, delete phase verifies artifact.phase is nil. Insert projection into phase, delete phase verifies projection is deleted. UserPreferences singleton behavior.

**Acceptance Criteria**
- Cascade delete of projections verified
- Nullify of artifact.phase verified
- Singleton enforcement verified
- All tests use in-memory ModelContainer

**Dependencies**
- Create ModelContainer factory with VersionedSchema

## Artifact Import Pipeline
**Goal:** Allow users to import images via drag-and-drop or file picker, generate thumbnails, store security-scoped bookmarks, and persist CreativeArtifact records

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement ArtifactImportService file validation (2h)

Create Services/ArtifactImportService.swift. Implement @Observable final class conforming to Sendable. Add method validateFile(url: URL) throws that checks UTType conforms to .image (JPEG, PNG, TIFF, HEIC, WebP) and file size <= 100MB. Define ImportError enum with cases unsupportedFormat, fileTooLarge, thumbnailGenerationFailed, duplicateArtifact.

**Acceptance Criteria**
- Rejects non-image files with unsupportedFormat error
- Rejects files > 100MB with fileTooLarge error
- Accepts JPEG, PNG, TIFF, HEIC, WebP
- ImportError conforms to LocalizedError with user-friendly descriptions

**Dependencies**
- Create ModelContainer factory with VersionedSchema

### ✅ Implement thumbnail generation with vImage (3h)

Add generateThumbnail(for imageURL: URL, maxDimension: CGFloat = 512) async throws -> CGImage to ArtifactImportService. Use CGImageSource to load, then vImage or CGContext to scale maintaining aspect ratio. Return CGImage. Convert to JPEG Data for storage.

**Acceptance Criteria**
- Output image fits within maxDimension on both axes
- Aspect ratio preserved
- Works with JPEG, PNG, HEIC inputs
- Resulting JPEG Data is under 100KB for typical photos

**Dependencies**
- Implement ArtifactImportService file validation

### ✅ Implement security-scoped bookmark creation and resolution (2h)

Add methods to ArtifactImportService: createBookmark(for url: URL) throws -> Data and resolveBookmark(_ data: Data) throws -> URL. Use URL.bookmarkData(options: .withSecurityScope) and URL(resolvingBookmarkDataFrom:options:bookmarkDataIsStale:). Handle stale bookmarks by returning nil and logging.

**Acceptance Criteria**
- Bookmark created from user-selected URL
- Bookmark resolves back to accessible URL
- Stale bookmark detected and logged without crash
- Works within App Sandbox

**Dependencies**
- Implement ArtifactImportService file validation

### ✅ Implement bulk import with AsyncThrowingStream (3h)

Add importArtifacts(from urls: [URL], into context: ModelContext) -> AsyncThrowingStream<ImportProgress, Error> to ArtifactImportService. ImportProgress = (current: Int, total: Int, artifact: CreativeArtifact?). For each URL: validate, generate thumbnail, create bookmark, insert CreativeArtifact into context, yield progress. Skip duplicates (check by bookmark data hash).

**Acceptance Criteria**
- Stream yields progress for each file
- Successful imports create CreativeArtifact with thumbnailData and bookmarkData
- Failed files yield progress with nil artifact and continue to next
- Duplicate detection works by comparing bookmark data
- Final yield has current == total

**Dependencies**
- Implement thumbnail generation with vImage
- Implement security-scoped bookmark creation and resolution

### ✅ Build ImportSheetView with drag-and-drop and file picker (3h)

Create Views/ImportSheetView.swift. Sheet view with a large drop zone accepting .image UTTypes. 'Browse Files' button triggers NSOpenPanel with allowedContentTypes for images, allowsMultipleSelection true. Progress bar showing current/total during import. Cancel button. Wire to ImportViewModel.

**Acceptance Criteria**
- Drag-and-drop accepts image files and highlights drop zone
- NSOpenPanel opens with correct file type filters
- Progress bar updates in real-time during import
- Cancel button stops ongoing import
- Sheet dismisses on completion

**Dependencies**
- Implement bulk import with AsyncThrowingStream

### ✅ Create ImportViewModel with @Observable (2h)

Create ViewModels/ImportViewModel.swift. @Observable class with importProgress (ImportProgress?), isImporting (Bool), errorMessage (String?). Method startImport(urls: [URL]) that calls ArtifactImportService.importArtifacts and iterates the stream, updating progress. Method cancelImport() that cancels the task.

**Acceptance Criteria**
- isImporting is true during import, false after
- importProgress updates on each stream yield
- Errors surface in errorMessage
- cancelImport stops the stream

**Dependencies**
- Implement bulk import with AsyncThrowingStream

### ✅ Write integration test for full import pipeline (2h)

Test: Create 5 test PNG images in a temp directory. Run importArtifacts through the full pipeline. Verify 5 CreativeArtifact records in SwiftData with non-nil thumbnailData, non-nil imageBookmarkData, nil styleVectorData, and correct importDate.

**Acceptance Criteria**
- 5 artifacts created with correct data
- thumbnailData is non-empty JPEG data
- styleVectorData is nil (not yet extracted)
- Test cleans up temp files

**Dependencies**
- Implement bulk import with AsyncThrowingStream

## Core ML Style Vector Extraction
**Goal:** Extract 33-dimensional style vectors from imported artifacts using Core ML, including color quantization, composition analysis, and texture features

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create or source the StyleFeatureExtractor Core ML model (8h)

Use Apple Vision framework's VNFeaturePrintObservation to extract a 2048-dim feature vector from images. Apply PCA reduction (pre-computed transformation matrix) to reduce to 33 dimensions matching StyleVector layout. Package the PCA matrix as a .mlmodelc or hardcoded Float array. This avoids training a custom model for v1.

**Acceptance Criteria**
- VNFeaturePrintObservation extracts features from test images
- PCA matrix reduces 2048-dim to 33-dim vector
- Output maps cleanly to StyleVector fields (5 color slots, 8 composition, 4 texture, 1 complexity)
- Runs on ANE/GPU automatically via Core ML runtime

**Dependencies**
- Create Xcode project with Swift 6 language mode

### ✅ Implement ColorQuantizer with k-means on pixel data (3h)

Create CoreML/ColorQuantizer.swift. Implement struct with static func dominantColors(from image: CGImage, count: Int = 5) -> [SIMD4<Float>]. Sample pixels (stride every Nth pixel for performance), run k-means with k=count on RGB values, return centroids sorted by cluster size (most dominant first). Output as RGBA with alpha=1.0.

**Acceptance Criteria**
- Solid red image returns one dominant red cluster
- Gradient image returns spread of colors
- Always returns exactly `count` colors
- Runs in under 50ms for a 512x512 image

**Dependencies**
_None_

### ✅ Implement StyleVectorExtractor single-image extraction (4h)

Create Services/StyleVectorExtractor.swift. Final class, Sendable. Method extractVector(from image: CGImage) async throws -> StyleVector. Use VNFeaturePrintObservation for composition/texture/complexity dimensions. Use ColorQuantizer for colorPalette. Combine into StyleVector. Define ExtractionError enum.

**Acceptance Criteria**
- Returns StyleVector with all 33 dimensions populated
- colorPalette has exactly 5 entries from ColorQuantizer
- ExtractionError.inferenceFailed thrown on bad input
- Runs async without blocking main thread

**Dependencies**
- Create or source the StyleFeatureExtractor Core ML model
- Implement ColorQuantizer with k-means on pixel data

### ✅ Implement StyleVectorExtractor batch extraction (3h)

Add batchExtract(from artifacts: [CreativeArtifact], context: ModelContext, concurrency: Int = 4) -> AsyncThrowingStream<(CreativeArtifact, StyleVector), Error> to StyleVectorExtractor. Use TaskGroup with bounded concurrency. For each artifact: resolve thumbnail from thumbnailData to CGImage, extract vector, update artifact.styleVectorData in-place, yield pair.

**Acceptance Criteria**
- Respects concurrency limit (max 4 simultaneous extractions by default)
- Updates artifact.styleVectorData in the ModelContext
- Yields partial results — if artifact 3 of 10 fails, first 2 results still yielded
- Stream completes after all artifacts processed

**Dependencies**
- Implement StyleVectorExtractor single-image extraction

### ✅ Write unit tests for ColorQuantizer (2h)

Test with: solid red 100x100 image (expect red cluster), 50/50 split red+blue image (expect red and blue clusters), gradient image (expect spread). Verify output count always matches requested count.

**Acceptance Criteria**
- Solid color test passes with tolerance 0.01
- Two-color split test identifies both colors
- Output array length equals requested count
- Tests run without network or file system

**Dependencies**
- Implement ColorQuantizer with k-means on pixel data

### ✅ Write integration test for import + extraction pipeline (2h)

Import 5 test images via ArtifactImportService, then run StyleVectorExtractor.batchExtract. Verify all 5 artifacts have non-nil styleVectorData with version byte 1 and decodable StyleVector.

**Acceptance Criteria**
- All 5 artifacts have styleVectorData after extraction
- Decoded StyleVectors have valid float ranges
- Version byte is 1 for all
- Test uses in-memory ModelContainer

**Dependencies**
- Implement StyleVectorExtractor batch extraction
- Write integration test for full import pipeline

## Evolution Engine
**Goal:** Cluster artifacts into aesthetic phases using k-means, compute style trajectory with velocity and acceleration, and persist phase data

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement k-means clustering on StyleVector arrays (3h)

Create Services/EvolutionEngine.swift. Final class, Sendable. Implement private func kMeans(vectors: [[Float]], k: Int, maxIterations: Int = 100, tolerance: Float = 1e-6) -> (centroids: [[Float]], assignments: [Int]). Flatten StyleVector to [Float] for computation. Early termination when centroid movement < tolerance.

**Acceptance Criteria**
- Correctly clusters 3 well-separated 2D point groups
- Terminates early when converged
- Respects maxIterations cap
- Returns correct assignments array matching vector indices

**Dependencies**
- Define StyleVector Codable struct with version-prefixed encoding

### ✅ Implement elbow method for automatic cluster count detection (2h)

Add private func elbowMethod(vectors: [[Float]], kRange: ClosedRange<Int> = 2...10) -> Int. Run k-means for each k, compute within-cluster sum of squares (WCSS). Select k at the elbow point using the maximum second derivative of the WCSS curve.

**Acceptance Criteria**
- Returns k=3 for data with 3 obvious clusters
- Returns k=2 for clearly bimodal data
- Handles edge case where all k values have similar WCSS (returns minimum k)
- Runs k-means for each candidate k

**Dependencies**
- Implement k-means clustering on StyleVector arrays

### ✅ Implement computePhases with chronological ordering (4h)

Add computePhases(from artifacts: [CreativeArtifact], clusterCount: Int? = nil) async throws -> [AestheticPhase]. Extract style vectors, flatten, run k-means (with elbow if clusterCount nil). For each cluster: compute centroid, determine dateRange from member artifact importDates, create AestheticPhase, assign artifacts to phase. Sort phases by dateRangeStart. Insert into ModelContext.

**Acceptance Criteria**
- Throws insufficientArtifacts if < 5 artifacts
- Throws missingStyleVectors if any artifact lacks vector
- Phases sorted chronologically by dateRangeStart
- All artifacts assigned to exactly one phase
- Phases persisted in SwiftData

**Dependencies**
- Implement elbow method for automatic cluster count detection
- Define AestheticPhase SwiftData model

### ✅ Implement computeTrajectory for velocity and acceleration (2h)

Add computeTrajectory(from phases: [AestheticPhase]) async -> StyleTrajectory. StyleTrajectory = (vectors: [StyleVector], velocity: StyleVector, acceleration: StyleVector). Velocity is the average difference between consecutive centroids. Acceleration is the difference of differences (second derivative). Throws if fewer than 2 phases.

**Acceptance Criteria**
- Linear trajectory (3 equally spaced centroids) produces constant velocity and near-zero acceleration
- Accelerating trajectory (increasing spacing) produces non-zero acceleration
- Throws insufficientPhases for < 2 phases
- Velocity and acceleration have same dimensionality as StyleVector

**Dependencies**
- Implement computePhases with chronological ordering

### ✅ Write unit tests for k-means and elbow method (2h)

Test k-means with synthetic 2D data: 3 Gaussian blobs (verify cluster membership), collinear points (verify 2 clusters). Test elbow method with known-k datasets. Test edge cases: single-point clusters, all-identical vectors.

**Acceptance Criteria**
- 3-blob test assigns points to correct clusters
- Elbow method selects correct k for synthetic data
- Single-point cluster handled without crash
- All-identical vectors produces k=2 with identical centroids

**Dependencies**
- Implement elbow method for automatic cluster count detection

### ✅ Write unit tests for trajectory computation (1.5h)

Test with 3 linearly-spaced phases: verify velocity is constant, acceleration near zero. Test with 3 phases having accelerating spacing: verify non-zero acceleration. Test with exactly 2 phases: verify velocity computed, acceleration is zero vector.

**Acceptance Criteria**
- Linear trajectory passes with float tolerance 1e-4
- Accelerating trajectory has non-trivial acceleration
- 2-phase edge case works correctly

**Dependencies**
- Implement computeTrajectory for velocity and acceleration

### ✅ Write integration test for full evolution pipeline (3h)

Import 20 test images with staggered importDates, extract vectors, run computePhases with auto cluster count. Verify phases created, chronologically ordered, all artifacts assigned, and trajectory computable.

**Acceptance Criteria**
- At least 2 phases created from 20 artifacts
- Phases are chronologically ordered
- All 20 artifacts assigned to a phase
- computeTrajectory succeeds on the resulting phases

**Dependencies**
- Implement computeTrajectory for velocity and acceleration
- Write integration test for import + extraction pipeline

## Projection Generator
**Goal:** Project future style directions from trajectory data and generate actionable palettes, layouts, and structural recommendations

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement forward projection from StyleTrajectory (3h)

Create Services/ProjectionGenerator.swift. Final class, Sendable. Method generateProjection(from trajectory: StyleTrajectory, steps: Int = 1) async throws -> [StyleProjection]. For each step: extrapolate next vector by adding velocity * step + 0.5 * acceleration * step^2 to the last centroid. Clamp all float values to valid ranges. Compute confidence = max(0.1, 1.0 - 0.2 * step).

**Acceptance Criteria**
- Linear trajectory produces linearly extrapolated projection
- Confidence decays by 0.2 per step, minimum 0.1
- All projected vector floats are within valid range [0, 1] for normalized dimensions
- Throws projectionOutOfBounds if step > 5

**Dependencies**
- Implement computeTrajectory for velocity and acceleration

### ✅ Implement palette generation from projected StyleVector (2h)

Add private method to ProjectionGenerator that converts the projected StyleVector.colorPalette ([SIMD4<Float>]) into [PaletteColor]. Generate hex strings from RGBA floats. Generate descriptive names using a lookup table based on HSL hue ranges (e.g., 'Warm Coral', 'Deep Navy'). Return 5 PaletteColor entries.

**Acceptance Criteria**
- Hex strings are valid #RRGGBB format
- Names are human-readable and match hue range
- Always returns exactly 5 palette colors
- Edge case: all-black and all-white palettes handled

**Dependencies**
- Define PaletteColor and LayoutGrid value types

### ✅ Implement layout grid generation from projected StyleVector (2h)

Add private method that maps projected StyleVector composition dimensions to LayoutGrid parameters. Map symmetry->columns (1-4), balance->rows (1-3), negative-space->gutterWidth (4-32), flow->aspectRatios. Use simple linear mapping from float ranges to grid parameter ranges.

**Acceptance Criteria**
- Columns in range 1-12, rows in range 1-6
- gutterWidth and marginWidth are non-negative
- aspectRatios array has length = columns * rows
- High-symmetry vectors produce even column counts

**Dependencies**
- Define PaletteColor and LayoutGrid value types

### ✅ Implement structural notes generation (2h)

Add private method that generates a human-readable String from the projected StyleVector. Describe dominant compositional traits (e.g., 'High symmetry with open negative space suggests a minimalist grid layout'). Use threshold-based rules on composition and texture dimensions.

**Acceptance Criteria**
- Output is 1-3 sentences of actionable compositional advice
- High-symmetry vectors mention 'symmetry' or 'balanced'
- High-texture vectors mention 'texture' or 'detail'
- Never returns empty string

**Dependencies**
_None_

### ✅ Persist StyleProjection to SwiftData (2h)

Wire generateProjection to create StyleProjection @Model instances. Encode palette as paletteJSON, layout as layoutJSON, set structuralNotes, confidence, creationDate, and sourcePhase relationship. Insert into ModelContext.

**Acceptance Criteria**
- StyleProjection record created and fetchable from ModelContext
- paletteJSON decodes back to [PaletteColor]
- layoutJSON decodes back to LayoutGrid
- sourcePhase relationship correctly set

**Dependencies**
- Implement forward projection from StyleTrajectory
- Implement palette generation from projected StyleVector
- Implement layout grid generation from projected StyleVector
- Implement structural notes generation
- Define StyleProjection SwiftData model

### ✅ Write unit tests for projection generator (2h)

Test: linear trajectory projects correctly at step 1 and 2. Confidence decays correctly. Palette hex generation for known RGBA values. Layout grid bounds for extreme vector values (all 0s, all 1s). Structural notes non-empty for various vectors.

**Acceptance Criteria**
- Projection math verified with tolerance 1e-4
- Confidence at step 1 = 0.8, step 5 = 0.1
- Hex conversion verified for (1,0,0,1) = '#FF0000'
- Layout bounds respected for extreme inputs

**Dependencies**
- Persist StyleProjection to SwiftData

## Gallery & Navigation Shell
**Goal:** Build the main app navigation with sidebar, artifact gallery, and detail views using NavigationSplitView and SwiftUI 6 features

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build NavigationSplitView app shell with sidebar (3h)

Create the root ContentView with NavigationSplitView (three-column). Sidebar shows list of AestheticPhase entries with labels and date ranges. Content column shows ArtifactGalleryView. Detail column shows artifact detail or evolution viewer. Wire .modelContainer modifier from App entry point.

**Acceptance Criteria**
- Three-column NavigationSplitView renders correctly
- Sidebar lists phases from SwiftData @Query
- Selecting a phase filters gallery to that phase's artifacts
- Empty state shown when no phases exist

**Dependencies**
- Create ModelContainer factory with VersionedSchema

### ✅ Build ArtifactGalleryView with LazyVGrid (3h)

Create Views/ArtifactGalleryView.swift. LazyVGrid with adaptive columns (minimum 120pt). Each cell shows artifact thumbnail decoded from thumbnailData. Tap selects artifact. Use @Query with SortDescriptor on importDate. Add FetchDescriptor with fetchLimit for pagination if library > 100.

**Acceptance Criteria**
- Thumbnails render from stored Data
- Grid adapts to window width
- Selecting artifact updates detail column
- Scrolling is smooth with 100+ artifacts (LazyVGrid)
- Empty state message when no artifacts

**Dependencies**
- Build NavigationSplitView app shell with sidebar

### ✅ Implement thumbnail cache with LRU eviction (2h)

Create an @Observable ThumbnailCache class with a dictionary of [PersistentIdentifier: CGImage] limited to 200 entries. LRU eviction when capacity exceeded. Decode thumbnailData to CGImage on background thread. Used by ArtifactGalleryView cells.

**Acceptance Criteria**
- Cache returns decoded CGImage for known artifact ID
- Evicts least-recently-used when over 200 entries
- Decoding happens off main thread
- Cache miss triggers async decode and updates view

**Dependencies**
- Build ArtifactGalleryView with LazyVGrid

### ✅ Build artifact detail view with matchedGeometryEffect (3h)

Create Views/ArtifactDetailView.swift. Shows full thumbnail, importDate, manual tags, style vector summary (if extracted). Transition from gallery cell uses matchedGeometryEffect with shared namespace. Show 'Extract Style' button if styleVectorData is nil.

**Acceptance Criteria**
- matchedGeometryEffect animates from gallery cell to detail
- All artifact metadata displayed
- Style vector summary shows key dimensions when available
- 'Extract Style' button triggers single-artifact extraction

**Dependencies**
- Build ArtifactGalleryView with LazyVGrid

### ✅ Create SidebarViewModel with @Observable (1.5h)

Create ViewModels/SidebarViewModel.swift. @Observable class with phases: [AestheticPhase] (from @Query), selectedPhase: AestheticPhase?, timelinePosition: Double (0.0-1.0). Methods for selecting phase and updating timeline position.

**Acceptance Criteria**
- phases populated from SwiftData
- selectedPhase updates when user taps sidebar item
- timelinePosition initializes to 0.0
- Changing selectedPhase filters artifacts in gallery

**Dependencies**
- Build NavigationSplitView app shell with sidebar

### ✅ Create GalleryViewModel with @Observable (1.5h)

Create ViewModels/GalleryViewModel.swift. @Observable class with artifacts: [CreativeArtifact], selectedArtifact: CreativeArtifact?, sortOrder: SortOrder enum (byDate, byPhase). Filter artifacts by selected phase from SidebarViewModel.

**Acceptance Criteria**
- Artifacts filtered by selected phase
- Sort order toggles between date and phase ordering
- Selecting artifact updates selectedArtifact
- Artifact list updates when SwiftData changes

**Dependencies**
- Create SidebarViewModel with @Observable

### ✅ Add MenuBarExtra for quick artifact import (2h)

In StylePhantomApp, add MenuBarExtra scene with systemImage 'paintbrush.pointed'. Menu items: 'Import Artifacts...' (opens import sheet), 'Recompute Evolution' (triggers evolution engine). Use @Environment(\.openWindow) for sheet presentation.

**Acceptance Criteria**
- Menu bar icon appears
- 'Import Artifacts...' opens import sheet
- 'Recompute Evolution' triggers phase recomputation
- Menu bar extra works when main window is closed

**Dependencies**
- Build ImportSheetView with drag-and-drop and file picker

## Evolution Viewer & Timeline
**Goal:** Build the side-by-side evolution viewer with drag-to-refine and the Metal-powered timeline scrubber for 60fps phase visualization

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build EvolutionViewerView with side-by-side comparison (4h)

Create Views/EvolutionViewerView.swift. HStack showing current phase summary (palette swatches, layout grid preview, centroid stats) on the left and projected next phase on the right. Each side renders PaletteSwatchView (row of colored rectangles) and LayoutGridPreview (rectangle grid with spacing). Use GeometryReader for responsive sizing.

**Acceptance Criteria**
- Current phase palette and layout displayed on left
- Projected phase palette and layout displayed on right
- Responsive to window resizing
- Empty state when no projection available

**Dependencies**
- Persist StyleProjection to SwiftData
- Build NavigationSplitView app shell with sidebar

### ✅ Implement drag-to-refine interaction (3h)

Add DragGesture to EvolutionViewerView. Horizontal drag interpolates between current phase centroid and projected vector. Compute interpolation factor t = clamp(drag.translation.width / viewWidth, 0, 1). Linearly interpolate StyleVector dimensions: result = current * (1-t) + projected * t. Regenerate palette and layout from interpolated vector in real-time. No re-clustering on drag.

**Acceptance Criteria**
- Dragging left shows current phase, right shows projection
- Palette and layout update smoothly during drag
- No re-clustering triggered during drag
- Release snaps to nearest endpoint or leaves at current position
- Performance: no frame drops during drag

**Dependencies**
- Build EvolutionViewerView with side-by-side comparison

### ✅ Create EvolutionViewModel with @Observable (2h)

Create ViewModels/EvolutionViewModel.swift. @Observable class with currentPhase: AestheticPhase?, projection: StyleProjection?, refinementOffset: CGSize, interpolatedPalette: [PaletteColor], interpolatedLayout: LayoutGrid. Methods: loadProjection(for phase:), updateRefinement(offset:), resetRefinement().

**Acceptance Criteria**
- loadProjection fetches or generates projection for selected phase
- updateRefinement computes interpolated palette and layout
- resetRefinement returns to t=0 state
- All properties trigger SwiftUI view updates

**Dependencies**
- Implement drag-to-refine interaction

### ✅ Write Metal shader for timeline gradient (3h)

Create Metal/TimelineShaders.metal. Implement timelineGradient shader that takes phase color data as a uniform buffer and renders smooth horizontal gradient bands. Each band represents a phase, colored by the dominant color from the phase centroid's colorPalette. Smooth blend at boundaries using smoothstep.

**Acceptance Criteria**
- Shader compiles without errors
- Renders colored bands for each phase
- Smooth blending between adjacent phases
- Accessible via ShaderLibrary.timelineGradient

**Dependencies**
- Create Xcode project with Swift 6 language mode

### ✅ Build TimelineScrubberView with TimelineView and Metal rendering (4h)

Create Views/TimelineScrubberView.swift. Use TimelineView with .animation schedule. Render phase timeline using Metal shader from ShaderLibrary. Show scrubber handle that can be dragged horizontally. Scrubber position maps to timelinePosition in SidebarViewModel. Display phase labels along the timeline.

**Acceptance Criteria**
- Timeline renders phase color bands via Metal shader
- Scrubber handle drags smoothly at 60fps
- Dragging scrubber updates selected phase
- Phase labels visible along timeline
- Works with 2-10 phases

**Dependencies**
- Write Metal shader for timeline gradient
- Create SidebarViewModel with @Observable

### ✅ Write Metal shader for style vector heatmap (3h)

Create vectorHeatmap shader in Metal/TimelineShaders.metal. Takes normalized StyleVector float array and renders a radial heatmap overlay. Center represents complexity, rings represent composition and texture dimensions. Color mapped from cool (blue) to warm (red) based on float values.

**Acceptance Criteria**
- Shader compiles and is accessible via ShaderLibrary.vectorHeatmap
- Renders radial pattern with correct color mapping
- All-zero vector renders cool/blue
- All-one vector renders warm/red
- Overlay is semi-transparent for compositing on artifacts

**Dependencies**
- Write Metal shader for timeline gradient

### ✅ Write Metal shader for evolution transition (2h)

Create evolutionTransition shader in Metal/TimelineShaders.metal. Custom wipe effect controlled by a float parameter (0.0 = fully left image, 1.0 = fully right image). Used in drag-to-refine to visually blend between current and projected states.

**Acceptance Criteria**
- Shader compiles and accessible via ShaderLibrary.evolutionTransition
- t=0 shows first color only, t=1 shows second color only
- Mid-values show smooth wipe transition
- No visual artifacts at edges

**Dependencies**
- Write Metal shader for timeline gradient

### ✅ Add PhaseAnimator for style evolution animations (2h)

In EvolutionViewerView, use PhaseAnimator to animate between phases when the user navigates the timeline. Animate palette swatch colors, layout grid dimensions, and structural notes text with spring animation. Trigger on selectedPhase change.

**Acceptance Criteria**
- Palette swatches animate color changes between phases
- Layout grid preview animates dimension changes
- Animation uses spring timing
- No animation on initial load, only on phase change

**Dependencies**
- Build EvolutionViewerView with side-by-side comparison

## Export System
**Goal:** Export projected palettes and layouts in multiple professional formats (ASE, JSON, CSS, SVG, Figma tokens) via NSSavePanel

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement ExportService palette export (JSON and CSS) (2h)

Create Services/ExportService.swift. Final class, Sendable. Method exportPalette(_ projection: StyleProjection, format: PaletteExportFormat, to url: URL) async throws. PaletteExportFormat enum: .json, .css. JSON format: array of {hex, name, rgba}. CSS format: :root with custom properties (--color-1: #hex; etc). Define ExportError enum.

**Acceptance Criteria**
- JSON output is valid and parseable
- CSS output is valid CSS with custom properties
- File written to user-specified URL
- ExportError.writePermissionDenied thrown when path not writable

**Dependencies**
- Persist StyleProjection to SwiftData

### ✅ Implement ExportService palette export (ASE format) (3h)

Add .ase case to PaletteExportFormat. Implement Adobe Swatch Exchange binary format: file header (ASEF magic bytes, version 1.0), group start block, color entries (name as UTF-16, RGB float values), group end block. Write as binary Data.

**Acceptance Criteria**
- Output file has correct ASEF magic bytes
- File loadable in Adobe applications or ASE-compatible tools
- Color values match projection palette within float tolerance
- File size reasonable (< 5KB for 5 colors)

**Dependencies**
- Implement ExportService palette export (JSON and CSS)

### ✅ Implement ExportService layout export (JSON and SVG) (3h)

Add exportLayout(_ projection: StyleProjection, format: LayoutExportFormat, to url: URL) async throws. LayoutExportFormat enum: .json, .svg. JSON: design-token compatible {columns, rows, gutter, margin, aspectRatios}. SVG: grid lines with spacing annotations as <line> and <text> elements.

**Acceptance Criteria**
- JSON output is valid design-token format
- SVG output is valid SVG viewable in browsers
- SVG shows grid lines and spacing annotations
- Both formats written to user-specified URL

**Dependencies**
- Implement ExportService palette export (JSON and CSS)

### ✅ Implement ExportService Figma tokens export (2h)

Add .figmaTokens case to LayoutExportFormat. Generate Figma design tokens JSON format with spacing, sizing, and color tokens derived from the projection. Follow Figma tokens plugin JSON structure.

**Acceptance Criteria**
- Output JSON matches Figma tokens plugin expected format
- Color tokens include all 5 palette colors
- Spacing tokens derived from layout grid
- File importable into Figma tokens plugin

**Dependencies**
- Implement ExportService layout export (JSON and SVG)

### ✅ Build ExportDialogView (2.5h)

Create Views/ExportDialogView.swift. Sheet with: format picker (segmented control for palette formats, separate for layout formats), preview of what will be exported, 'Export' button triggering NSSavePanel. Wire to ExportViewModel.

**Acceptance Criteria**
- Format picker shows all available formats
- Preview updates when format changes
- 'Export' button opens NSSavePanel with correct file extension
- Sheet dismisses on successful export

**Dependencies**
- Implement ExportService Figma tokens export

### ✅ Create ExportViewModel with @Observable (1.5h)

Create ViewModels/ExportViewModel.swift. @Observable class with selectedPaletteFormat: PaletteExportFormat, selectedLayoutFormat: LayoutExportFormat, isExporting: Bool, errorMessage: String?. Methods: exportPalette(_ projection:), exportLayout(_ projection:).

**Acceptance Criteria**
- Format selection persists during session
- isExporting true during file write
- Errors surface in errorMessage
- Successful export dismisses dialog

**Dependencies**
- Build ExportDialogView

### ✅ Write unit tests for ASE binary encoding (2h)

Test ASE output for known palettes: verify ASEF magic bytes at offset 0, verify version bytes, verify color entry count, verify RGB float values match input within tolerance.

**Acceptance Criteria**
- Magic bytes verified: 0x41534546
- Color count matches input palette size
- Float values within 1e-4 tolerance
- Test does not require external tools

**Dependencies**
- Implement ExportService palette export (ASE format)

### ✅ Write integration test for export pipeline (2h)

Generate a projection from test data, export in each format (ASE, JSON, CSS, SVG, Figma tokens), verify all files are non-empty and parseable (JSON files parse, SVG has valid XML, ASE has magic bytes).

**Acceptance Criteria**
- All 5 export formats produce non-empty files
- JSON files parse without error
- SVG validates as XML
- ASE has correct header
- Files cleaned up after test

**Dependencies**
- Implement ExportService Figma tokens export

## Settings & Preferences
**Goal:** Build the Settings scene for configuring export defaults, CloudKit sync toggle, and evolution parameters

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build SettingsView with Form (3h)

Create Views/SettingsView.swift. Use Settings scene in App. Form with sections: Export Defaults (pickers for default palette and layout format), Evolution (stepper for minimum artifact threshold, optional cluster count picker), Sync (toggle for CloudKit sync). Bind to UserPreferences singleton via ModelContext.

**Acceptance Criteria**
- Settings window opens from app menu
- All preferences editable via form controls
- Changes persist immediately to SwiftData
- CloudKit toggle shows confirmation alert

**Dependencies**
- Define UserPreferences SwiftData model with singleton pattern

### ✅ Build ProjectionConfigSheet (2h)

Create Views/ProjectionConfigSheet.swift. Sheet for configuring projection parameters before generation: stepper for projection steps (1-5), cluster count override (nil for auto, or 2-10), 'Generate' button. Shown from evolution viewer.

**Acceptance Criteria**
- Steps stepper works in range 1-5
- Cluster count toggle between auto and manual
- Generate button triggers projection with selected params
- Sheet dismisses on generate

**Dependencies**
- Build EvolutionViewerView with side-by-side comparison

### ✅ Apply NSWindow customization for premium feel (2h)

Add NSApplicationDelegateAdaptor to StylePhantomApp. In delegate, customize main window: .ultraThinMaterial vibrancy for sidebar, .titlebarAppearsTransparent, .toolbarStyle(.unified). Set minimum window size to 900x600.

**Acceptance Criteria**
- Sidebar has ultraThinMaterial vibrancy effect
- Titlebar is transparent with unified toolbar style
- Window respects minimum size
- Visual effect persists through window resize

**Dependencies**
- Build NavigationSplitView app shell with sidebar

### ✅ Write test for settings persistence (1h)

Change export format via UserPreferences, create new ModelContainer (simulating relaunch), fetch UserPreferences, verify changed value persists.

**Acceptance Criteria**
- Changed format value persists through container recreation
- Default values correct on fresh container
- Singleton fetch returns modified instance

**Dependencies**
- Build SettingsView with Form

## CloudKit Sync
**Goal:** Implement optional CloudKit sync for multi-Mac usage with background sync and conflict resolution

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Configure ModelContainer for CloudKit sync (3h)

Modify ModelContainerFactory to accept cloudKitEnabled parameter. When enabled, configure ModelContainer with CloudKit container identifier. Use CKContainer.default() private database. Add CloudKit entitlement to Xcode project. Background ModelContext for sync operations.

**Acceptance Criteria**
- CloudKit-enabled container initializes without error
- Non-CloudKit container still works when sync disabled
- CloudKit entitlement present in entitlements file
- Background ModelContext created for sync

**Dependencies**
- Create ModelContainer factory with VersionedSchema
- Build SettingsView with Form

### ✅ Implement sync toggle in UserPreferences (3h)

When user toggles cloudKitSyncEnabled in Settings, show confirmation alert explaining what will sync. On confirmation, recreate ModelContainer with CloudKit enabled. On disable, switch back to local-only container. Handle transition gracefully.

**Acceptance Criteria**
- Toggling on shows confirmation alert
- Container recreated with CloudKit on confirmation
- Toggling off switches to local-only without data loss
- Existing local data preserved during enable

**Dependencies**
- Configure ModelContainer for CloudKit sync

### ✅ Implement conflict resolution for style vectors (3h)

When CloudKit sync detects a conflict on CreativeArtifact.styleVectorData, use last-writer-wins based on a syncTimestamp field added to CreativeArtifact. The newer styleVectorData wins. Log conflicts at .info level.

**Acceptance Criteria**
- Newer styleVectorData overwrites older on conflict
- Conflict logged with both timestamps
- No data corruption on conflict resolution
- syncTimestamp updated on each local modification

**Dependencies**
- Implement sync toggle in UserPreferences

### ✅ Handle CloudKit quota and errors (2h)

Catch CKError cases: .quotaExceeded (show alert suggesting disabling thumbnail sync), .networkUnavailable (queue changes for retry), .serverRecordChanged (trigger conflict resolution). Surface user-actionable errors via alert. Non-actionable errors logged silently.

**Acceptance Criteria**
- Quota exceeded shows user-friendly alert
- Network unavailable queues changes without error UI
- Server conflicts trigger resolution logic
- No silent error swallowing for actionable errors

**Dependencies**
- Implement conflict resolution for style vectors

## Observability & Logging
**Goal:** Add structured logging, Instruments signpost integration, and performance metrics across all services

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Set up os.Logger with per-module categories (1h)

Create a Logging.swift file with static logger instances: Logger(subsystem: 'com.stylephantom.app', category: 'import'), 'extraction', 'evolution', 'projection', 'export', 'sync'. Use .debug for timing, .info for operation lifecycle, .error for failures.

**Acceptance Criteria**
- All 6 logger categories defined
- Subsystem is 'com.stylephantom.app'
- Loggers accessible from any service via static properties
- Visible in Console.app with subsystem filter

**Dependencies**
- Create Xcode project with Swift 6 language mode

### ✅ Add os.Signpost intervals for performance-critical operations (2h)

Add signpost intervals around: Core ML inference (per-image and batch), K-means clustering, export encoding, and thumbnail generation. Use OSSignpostIntervalBegin/End pattern. Enable Instruments Time Profiler and Core ML template analysis.

**Acceptance Criteria**
- Signposts visible in Instruments Time Profiler
- Core ML inference interval measurable per image
- K-means clustering total duration measurable
- No signpost overhead in release builds (os_signpost is optimized away)

**Dependencies**
- Set up os.Logger with per-module categories
- Implement StyleVectorExtractor batch extraction
- Implement k-means clustering on StyleVector arrays

### ✅ Add performance metrics logging (2h)

Log at .debug level: import throughput (artifacts/sec after batch), extraction latency (ms/artifact), clustering duration (total seconds), projection confidence distribution, peak memory during batch operations (via ProcessInfo.processInfo.physicalMemory sampling).

**Acceptance Criteria**
- Import throughput logged after each batch import
- Extraction latency logged per artifact
- Clustering duration logged at .info after computePhases
- Memory sampling logged during batch operations
- All metrics use structured log format

**Dependencies**
- Set up os.Logger with per-module categories

## End-to-End Testing & Performance
**Goal:** Validate complete user journeys, performance targets, and accessibility compliance

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Write E2E test for full user journey (4h)

UI test: Launch app -> open import sheet -> import 10 test images -> wait for extraction to complete -> navigate to timeline -> select a phase -> view projection in evolution viewer -> export palette as JSON -> verify file contents match projection data.

**Acceptance Criteria**
- Test passes end-to-end without manual intervention
- Exported JSON file contains valid palette data
- All UI transitions work (import sheet, timeline, evolution viewer, export)
- Test completes in under 30 seconds

**Dependencies**
- Create ExportViewModel with @Observable
- Build TimelineScrubberView with TimelineView and Metal rendering
- Create EvolutionViewModel with @Observable

### ✅ Write E2E test for empty state (2h)

UI test: Launch app with no artifacts -> verify empty state in gallery and sidebar -> import single image -> verify it appears in gallery -> verify sidebar shows 'insufficient artifacts' message (< 5).

**Acceptance Criteria**
- Empty gallery shows appropriate message
- Empty sidebar shows appropriate message
- Single imported image appears in gallery
- < 5 artifacts shows threshold warning

**Dependencies**
- Write E2E test for full user journey

### ✅ Write performance test for large library (500 artifacts) (4h)

Generate 500 synthetic test images with known style properties. Import all, extract vectors, compute evolution. Measure: import time, extraction time, evolution computation time (target < 3s), timeline scrubbing frame rate (target 60fps via CADisplayLink).

**Acceptance Criteria**
- Evolution computation completes in under 3 seconds for 500 artifacts
- Timeline scrubbing maintains 60fps (measured, not estimated)
- Memory usage stays under 500MB during batch operations
- No SwiftData query timeouts

**Dependencies**
- Write E2E test for full user journey

### ✅ Write E2E test for drag-to-refine interaction (2h)

UI test: Navigate to evolution viewer with a computed projection -> simulate horizontal drag gesture -> verify palette interpolation updates visually -> verify no frame drops during drag.

**Acceptance Criteria**
- Drag gesture simulated successfully in UI test
- Palette colors change during drag
- No crashes during rapid drag gestures
- Release returns to stable state

**Dependencies**
- Create EvolutionViewModel with @Observable

### ✅ Accessibility audit (VoiceOver and Dynamic Type) (3h)

Review all views for VoiceOver accessibility: add accessibilityLabel to palette swatches, artifact thumbnails, and timeline controls. Verify Dynamic Type works in SettingsView form. Add accessibilityHint for drag-to-refine gesture.

**Acceptance Criteria**
- All interactive elements have accessibilityLabel
- VoiceOver can navigate full app flow
- Settings form respects Dynamic Type
- Drag-to-refine has accessibilityHint explaining interaction

**Dependencies**
- Write E2E test for full user journey

### ✅ Profile with Instruments and optimize bottlenecks (4h)

Run Time Profiler, Core ML Instruments template, and Metal System Trace. Identify and fix: any frame drops in timeline scrubber, any main-thread Core ML inference, any SwiftData @Query in tight loops. Document findings.

**Acceptance Criteria**
- No frame drops below 55fps in timeline scrubber
- Core ML inference fully off main thread
- No @Query calls in per-cell rendering
- App launch under 2 seconds (cold start)

**Dependencies**
- Write performance test for large library (500 artifacts)

## Distribution
**Goal:** Package the app for Mac App Store or notarized DMG distribution with CI pipeline

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Configure Xcode Cloud CI pipeline (3h)

Set up Xcode Cloud workflow: trigger on push to main, run all unit and integration tests, build for release, archive. Configure code signing with automatic provisioning.

**Acceptance Criteria**
- CI builds trigger on push to main
- All tests run in CI
- Build succeeds with release configuration
- Archive produced for distribution

**Dependencies**
- Profile with Instruments and optimize bottlenecks

### ✅ Prepare Mac App Store metadata and submission (4h)

Create App Store Connect listing: app name, description, screenshots (5 required sizes), category (Graphics & Design). Set up TestFlight beta group. Submit for review. Alternatively, prepare notarized DMG with create-dmg.

**Acceptance Criteria**
- App Store listing created with all required metadata
- Screenshots captured for required sizes
- TestFlight build uploaded and distributed to testers
- OR: Notarized DMG produced and downloadable

**Dependencies**
- Configure Xcode Cloud CI pipeline

## ❓ Open Questions
- Should VNFeaturePrintObservation PCA matrix be pre-computed from a representative dataset or computed on-the-fly from the user's own artifacts?
- Should the elbow method auto-detection show the user its recommended k with an option to override, or silently use the auto-detected value?
- When the Core ML model changes in a future version, should existing artifacts be automatically re-extracted in background or require manual trigger?
- Should CloudKit sync include thumbnailData or only metadata (regenerating thumbnails from originals on each Mac)?
- For drag-to-refine, is linear interpolation between style vectors sufficient for v1 or should cubic interpolation be explored?
- Should palette color naming use a static HSL lookup table or leverage NaturalLanguage framework for more creative names?