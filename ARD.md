# Architecture Requirements Document

## 🧱 System Overview
Style Phantom is a local-first macOS creative intelligence app that analyzes a creator's body of work to map their aesthetic taste evolution and project future style directions. All processing runs on-device using Core ML for style vector extraction and K-means clustering, SwiftData for persistence, and SwiftUI 6 for a premium fluid interface. The app imports creative artifacts as images, extracts multi-dimensional style vectors, clusters them into aesthetic phases along a timeline, and generates projected next-evolution palettes, layouts, and structures that users can apply to new projects via one-click export.

## 🏗 Architecture Style
Single-process macOS app using clean layered architecture: SwiftUI 6 presentation layer with Observation framework view models, a domain services layer for style analysis and evolution projection, a Core ML inference layer for on-device AI, and a SwiftData persistence layer with optional CloudKit sync. No server, no network dependency for core functionality. All layers communicate through Swift 6 Structured Concurrency with strict Sendable compliance.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI 6 targeting macOS 15+ (Sequoia) with NSWindow customization for .ultraThinMaterial and .regularMaterial vibrancy. Uses matchedGeometryEffect for fluid gallery transitions, PhaseAnimator for multi-step style evolution animations, and TimelineView with Metal shaders for the 60fps evolution timeline scrubber. Settings scene for preferences, optional menu bar accessory for quick artifact import.
- **State Management:** Observation framework (@Observable view models) as the single state management pattern. Each major view has a dedicated @Observable view model that owns its domain logic and exposes published state. SwiftData @Query used directly in views for artifact browsing. No Combine, no ObservableObject — pure Observation framework throughout for Swift 6 strict concurrency compliance.
- **Routing:** NavigationSplitView as the root layout: sidebar for aesthetic phase clusters and timeline navigation, content area for artifact gallery grid, and detail area for the side-by-side evolution viewer. Sheet presentations for artifact import, style projection configuration, and export dialogs. No deep-linking or URL routing needed for a local desktop app.
- **Build Tooling:** Xcode 16+ with Swift 6 language mode enabled. Swift Package Manager for any internal modularization. No external package dependencies required — Core ML, SwiftData, CloudKit, Metal, and NaturalLanguage are all first-party frameworks.

## 🧠 Backend Architecture
- **Approach:** No server backend. All logic runs in-process as Swift domain services coordinated through Structured Concurrency. The app uses a service layer pattern where lightweight Swift actor or @Observable service objects encapsulate domain operations (artifact import, style vector extraction, evolution clustering, projection generation) and expose async APIs to the view layer.
- **API Style:** No network API. Internal service interfaces are Swift async functions and AsyncSequences. Services communicate through direct method calls coordinated by view models. Heavy computation (Core ML inference, K-means clustering) runs in detached tasks or task groups to keep the main actor responsive.
- **Services:**
- ArtifactImportService: Handles file system access, image validation, thumbnail generation, and bulk import with progress reporting via AsyncSequence.
- StyleVectorExtractor: Wraps Core ML inference to extract multi-label style vectors (color palette, composition, texture, complexity) from artifact images. Runs on a background TaskGroup for parallel processing.
- EvolutionEngine: Performs K-means clustering on style vectors to identify aesthetic phases, orders them chronologically, and computes trajectory vectors between cluster centroids to project future style directions.
- ProjectionGenerator: Takes trajectory vectors from EvolutionEngine and generates concrete next-evolution outputs: color palettes (as ASE-compatible values), layout grid suggestions, and structural recommendations.
- ExportService: Formats projection outputs for one-click apply — color palette files, design token JSON, and SVG layout grids written to user-specified locations.

## 🗄 Data Layer
- **Primary Store:** SwiftData with a single ModelContainer initialized at app launch. Models: CreativeArtifact (image reference, import date, thumbnail, style vector as encoded Data, manual tags), AestheticPhase (cluster centroid vector, date range, member artifact relationships, phase label), StyleProjection (projected vector, generated palette, layout suggestion, confidence score, creation date), UserPreferences (export format settings, minimum artifact threshold, CloudKit sync toggle).
- **Relationships:** CreativeArtifact has a many-to-one relationship with AestheticPhase (each artifact belongs to one detected phase). AestheticPhase has a one-to-many relationship with StyleProjection (each phase can generate multiple forward projections). All relationships use SwiftData @Relationship macros with cascade delete rules from Phase to its Projections.
- **Migrations:** SwiftData lightweight migration with VersionedSchema. Initial schema is V1. Future schema changes use SchemaMigrationPlan with MigrationStage definitions. Style vector encoding format is versioned in the CreativeArtifact model to allow vector dimension changes without full data migration.

## ☁️ Infrastructure
- **Hosting:** Fully local macOS application distributed via Mac App Store or direct notarized DMG download. No server infrastructure. Optional CloudKit sync uses the user's private iCloud database for multi-Mac artifact and style vector synchronization — no Anthropic/developer-managed servers involved.
- **Scaling Strategy:** Scales vertically with Apple Silicon hardware. Core ML inference leverages ANE (Apple Neural Engine) and GPU automatically. K-means clustering runs in-memory with TaskGroup parallelism across available CPU cores. For large artifact libraries (500+), evolution computation uses incremental clustering — new artifacts are assigned to existing clusters or trigger a bounded re-clustering rather than full recomputation. Image thumbnails and style vectors are cached in SwiftData to avoid redundant Core ML inference.
- **CI/CD:** Xcode Cloud for automated builds, testing, and TestFlight distribution. Swift 6 strict concurrency warnings treated as errors in CI. Unit tests for domain services (style vector extraction accuracy, clustering correctness). UI tests for critical flows (import, timeline scrubbing, export). No server deployment pipeline needed.

## ⚖️ Key Trade-offs
- Local-only Core ML inference limits model size to under 200MB and restricts style analysis to what can run on-device, but guarantees complete privacy and eliminates network latency.
- SwiftData over Core Data reduces boilerplate and gains CloudKit sync integration for free, but limits deployment to macOS 15+ and constrains query flexibility compared to raw Core Data fetch requests.
- Single-process architecture with no microservices keeps the system simple and debuggable, but means heavy Core ML inference must be carefully dispatched to background threads to avoid UI jank.
- K-means clustering is chosen over more sophisticated models (DBSCAN, hierarchical) for evolution detection because it is fast, deterministic, and produces clean phase boundaries — at the cost of requiring a pre-set cluster count or an elbow-method heuristic.
- Style vectors are stored as opaque encoded Data blobs in SwiftData rather than as individual float columns, trading query-time filtering on vector dimensions for simpler schema evolution when vector formats change.
- Optional CloudKit sync adds multi-Mac support but introduces eventual consistency complexity and limits synced data to CloudKit record size constraints. Keeping it optional avoids forcing iCloud dependency on privacy-conscious users.

## 📐 Non-Functional Requirements
- All Core ML inference runs on-device with zero network calls. No telemetry or analytics data leaves the machine.
- App launch to interactive gallery in under 2 seconds on Apple Silicon Macs.
- Single artifact style vector extraction completes in under 500ms on M1 or later.
- Evolution projection for up to 500 artifacts completes in under 3 seconds.
- Evolution timeline viewer maintains 60fps during scrubbing with 200+ loaded artifacts, using Metal shaders and TimelineView for rendering.
- Full Swift 6 strict concurrency compliance — all types are Sendable, all cross-isolation calls use structured concurrency, no data races.
- Core ML model bundle size stays under 200MB to keep the app download reasonable.
- Minimum deployment target is macOS 15 (Sequoia). No backward compatibility shims.
- CloudKit sync, when enabled, operates in the background without blocking UI and handles conflict resolution with last-writer-wins semantics on style vectors.