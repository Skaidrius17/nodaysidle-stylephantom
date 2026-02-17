# Style Phantom — User Guide

Welcome to Style Phantom, your personal creative taste tracker. This guide walks you through everything the app can do.

---

## Getting Started

### First Launch

When you open Style Phantom for the first time, you'll see the three-column interface with empty state prompts guiding you to import your first artwork.

### Importing Your Work

There are three ways to import:

1. **Sidebar button** — Click **"Import Artifacts"** in the sidebar
2. **Keyboard shortcut** — Press **CMD + Shift + I**
3. **Menu bar** — Click the paintbrush icon in your menu bar and select "Import Artifacts"

In the import sheet:

- Click **"Choose Files"** to select images from Finder
- Or **drag and drop** files directly onto the drop zone
- Supported formats: **PNG, JPEG, TIFF, HEIC**
- Maximum file size: **50 MB per image**

After selecting files, click **"Import"** and Style Phantom will:

1. Validate each file (format, size, duplicates)
2. Generate optimized thumbnails
3. Create security-scoped bookmarks for future access
4. Display them in your gallery

---

## The Gallery

### Browsing

Your imported artwork appears as a responsive grid. Each card shows:

- A thumbnail of the artwork
- The import date
- A **sparkle icon** if style vectors have been extracted
- A **colored dot** indicating which aesthetic phase it belongs to

### Sorting & Searching

Use the toolbar controls to:

- **Sort** by date (newest/oldest), name, or phase
- **Search** by filename using the search field

### Selecting an Artifact

Click any card to see its full detail in the right panel, including:

- Full-size preview
- Import date and assigned phase
- **Dominant Colors** — 5 extracted color swatches with hex values
- **Composition** — 8 dimension bars (thirds, symmetry, focal point, negative space, depth, layering, balance, flow)
- **Complexity** — Overall visual complexity gauge
- **Tags** — Any labels you've added

---

## Extracting Style

For each artifact, you can extract its style vector:

1. Select an artifact in the gallery
2. Click **"Extract Style"** in the detail panel
3. Wait for the extraction to complete (usually under a second)

The extraction analyzes your image and computes a **33-dimensional style vector** capturing:

| Dimension | Count | What It Measures |
|-----------|-------|------------------|
| Color Palette | 20 | 5 dominant colors (RGBA each) |
| Composition | 8 | Spatial balance, symmetry, focal points |
| Texture | 4 | Surface quality, pattern density |
| Complexity | 1 | Overall visual intricacy |

---

## Evolution Engine

### Computing Phases

Once you have **5 or more artifacts** with extracted style vectors, you can compute your aesthetic evolution:

1. Click **"Recompute Evolution"** in the sidebar
2. The engine will:
   - Cluster your work into aesthetic phases using k-means
   - Automatically determine the optimal number of phases (elbow method)
   - Compute your style trajectory and acceleration
   - Generate a projection of where your taste is heading

### Aesthetic Phases

Each phase appears in the sidebar with:

- A **colored dot** matching the phase's dominant color
- A **label** describing the phase (e.g., "Warm Minimalism", "High Contrast")
- The **date range** it spans

Click a phase to filter the gallery to only show artifacts from that period.

---

## Evolution Viewer

The Evolution Viewer is the heart of Style Phantom. To open it:

- Click **"Evolution Viewer"** in the sidebar (appears after computing phases)

### What You See

The viewer shows two columns side by side:

| Left Column | Right Column |
|-------------|-------------|
| **Current Phase** — Your most recent aesthetic | **Projected** — Where your style is heading |
| Real palette and layout from your work | AI-generated palette and layout from projection |
| Confidence: 100% | Confidence: varies (shown as percentage) |

Each column displays:

- **Color Palette** — Swatches with names and hex codes
- **Layout Grid** — Visual grid with column/row structure
- **Grid Stats** — Columns, rows, gutter width, margin width

### Drag to Refine

This is the magic part: **drag horizontally** anywhere on the viewer to interpolate between your current style and the projected direction.

- **Drag right** — Move toward the projection (higher refinement %)
- **Drag left** — Move back toward your current style (lower refinement %)
- The **refinement percentage** is shown in the header

The palette and layout update in real-time as you drag, blending smoothly between the two states. This lets you find the exact sweet spot between where you are and where you might want to go.

### Structural Notes

Below the viewer, you'll find AI-generated structural notes describing the characteristics of the interpolated style — things like color temperature, contrast levels, and compositional tendencies.

---

## Timeline

At the bottom of the window, the **Timeline Scrubber** shows your aesthetic journey as colored phase bands:

- Each band's color matches the phase's dominant hue
- **Phase markers** (circles) show where each phase is centered
- **Drag the scrubber** to travel through time
- Clicking a phase marker snaps to that phase

The timeline only appears when you have 2 or more computed phases.

---

## Exporting

### Opening the Export Dialog

Click the **"Export"** button in the Evolution Viewer header to open the export dialog.

### Export Modes

Toggle between two export modes:

**Palette Export:**

| Format | What You Get |
|--------|-------------|
| JSON | Array of color objects with hex, name, and RGBA values |
| CSS | `:root` block with CSS custom properties (`--color-name: #hex`) |
| ASE | Adobe Swatch Exchange binary — opens in Photoshop, Illustrator, InDesign |

**Layout Export:**

| Format | What You Get |
|--------|-------------|
| JSON | Design token object with grid properties |
| SVG | Visual grid overlay with labeled cells |
| Figma Tokens | Token Studio-compatible JSON for Figma |

### Preview

Before exporting, the dialog shows a live preview of the output in monospaced text. You can select and copy text directly from the preview.

### Saving

Click **"Export..."** to open a save dialog. The file extension is automatically set based on your chosen format.

---

## Settings

Open Settings with **CMD + ,** (or from the app menu).

### Export Defaults

- **Default Palette Format** — Choose JSON, CSS, or ASE
- **Default Layout Format** — Choose JSON, SVG, or Figma Tokens

### Evolution Parameters

- **Minimum Artifacts** — How many artifacts are needed before computing phases (default: 5)
- **Max Cluster Count** — Upper limit for automatic phase detection (default: 8)

### Sync

- **iCloud Sync** — Toggle CloudKit sync for multi-Mac setups (when available)

---

## Menu Bar

Look for the **paintbrush icon** in your macOS menu bar for quick access to:

- **Import Artifacts** (CMD + Shift + I)
- **Recompute Evolution**
- **Quit** (CMD + Q)

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| CMD + Shift + I | Import artifacts |
| CMD + , | Open Settings |
| CMD + Q | Quit |
| Escape | Close sheets and dialogs |

---

## Tips & Tricks

- **Import in batches** — Drop 20-50 pieces at once for faster phase detection
- **Variety helps** — The more diverse your imports, the more interesting the phases
- **Re-extract after updates** — If the app updates its extraction algorithm, re-extract vectors for better results
- **Use the drag** — The interpolation slider is the best way to discover unexpected color combinations
- **Export to your tools** — ASE files open directly in Adobe apps; Figma Tokens work with the Token Studio plugin

---

## Troubleshooting

### "Not enough artifacts" error
You need at least 5 artifacts with extracted style vectors before computing evolution. Import more work and extract their style vectors.

### Phases seem wrong
Try re-running **Recompute Evolution** after importing more diverse work. The engine needs variety to find meaningful clusters.

### App won't build
Make sure you have Swift 6.2+ installed:
```bash
swift --version
```
If you see an older version, update Xcode Command Line Tools.

---

## Privacy

Everything runs **100% on your Mac**. No data is sent anywhere. No telemetry, no analytics, no cloud processing. Your creative work stays private.

---

*Style Phantom v0.1.0 — Built with SwiftUI 6 + SwiftData + Metal*
