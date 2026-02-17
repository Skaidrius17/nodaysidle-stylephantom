# Style Phantom

## 🎯 Product Vision
A macOS-native creative intelligence tool that captures the invisible evolution of your personal creative taste and generates 'next evolution' palettes, layouts, and structures you didn't know you wanted — all processed entirely on-device.

## ❓ Problem Statement
Creators plateau because they can't see their own taste trajectory. Without visibility into how their aesthetic preferences have evolved over time, they recycle the same patterns and miss opportunities to grow. There is no tool that analyzes a creator's body of work, maps their style evolution, and projects where their taste is heading next.

## 🎯 Goals
- Help creators visualize how their aesthetic taste has evolved across their body of work
- Generate projected 'next evolution' palettes, layouts, and structural suggestions based on detected taste trajectory
- Enable one-click application of generated style evolutions to new projects
- Provide a side-by-side evolution viewer for comparing past, present, and projected future styles
- Keep all processing local and private using on-device Core ML inference
- Deliver a premium, fluid macOS experience with polished animations and material effects

## 🚫 Non-Goals
- Building a general-purpose design tool or editor
- Providing server-side processing or cloud-based AI inference
- Supporting platforms other than macOS 15+ (Sequoia)
- Replacing existing creative tools like Figma, Sketch, or Photoshop
- Social features, sharing, or community galleries
- Real-time collaboration

## 👥 Target Users
- Independent graphic designers and illustrators who want to understand their evolving aesthetic
- UI/UX designers seeking to break out of repetitive design patterns
- Digital artists and creative professionals who maintain a portfolio of past work
- Brand designers who need to evolve visual identities intentionally over time

## 🧩 Core Features
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]
- [object Object]

## ⚙️ Non-Functional Requirements
- All AI inference must run on-device using Core ML with no network dependency
- Local-first architecture with SwiftData persistence and optional CloudKit sync for multi-Mac setups
- App launch to interactive gallery in under 2 seconds on Apple Silicon
- Style vector analysis of a single artifact must complete in under 500ms on M1 or later
- Evolution projection for up to 500 artifacts must complete in under 3 seconds
- Fluid 60fps animations for the evolution timeline viewer using Metal shaders and PhaseAnimator
- Premium window appearance using NSWindow customization with .ultraThinMaterial and .regularMaterial vibrancy
- Full Swift 6 strict concurrency compliance using Structured Concurrency and the Observation framework
- macOS 15+ (Sequoia) minimum deployment target
- Privacy-preserving: no telemetry, no data leaves the device unless CloudKit sync is explicitly enabled

## 📊 Success Metrics
- 80% of users import at least 20 creative artifacts within the first week
- Users engage with the evolution timeline viewer at least 3 times per week
- 60% of generated 'next evolution' suggestions are rated useful or applied by the user
- Style vector analysis accuracy exceeds 85% agreement with manual style labeling in user testing
- App maintains 60fps during timeline scrubbing with 200+ artifacts loaded
- Less than 1% crash rate across all user sessions

## 📌 Assumptions
- Users have a body of past creative work (at least 10-20 artifacts) available as image files for import
- Target machines are Apple Silicon Macs running macOS 15+ with sufficient GPU for Core ML inference
- Style evolution can be meaningfully represented as movement through a multi-dimensional vector space
- K-means clustering on style vectors produces perceptually meaningful groupings of aesthetic phases
- Users will trust and find value in algorithmically projected style directions
- Core ML model size can remain under 200MB for reasonable app bundle size

## ❓ Open Questions
- What specific style dimensions should the multi-label style vectors encode (color palette, composition, typography, texture, complexity)?
- Should the Core ML evolution model be pre-trained with a base aesthetic model and fine-tuned per user, or trained from scratch on user data only?
- What export formats are most valuable for one-click apply (ASE color palettes, SVG layout grids, design tokens JSON)?
- How should the app handle users with very few artifacts — is there a minimum threshold before evolution projection is meaningful?
- Should CloudKit sync include the trained per-user Core ML model or only the raw artifacts and style vectors?
- What is the right UX for the drag-to-refine interaction — continuous sliders along style axes, or a 2D canvas mapping two dimensions at a time?