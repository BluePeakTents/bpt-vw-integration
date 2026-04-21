# Extraction Request for Claude Code Build

## Who This Is For
**Jon's Claude Project** — compile and return the deliverables below so Claude Code can build the Layout tab into the Blue Peak Sales Hub (`bpt-sales-app`).

## Context
We are building a "Layout" tab inside the Sales Hub for each Deal. The tab lets sales reps auto-generate tent + furniture layouts via Claude API, visually edit them in a React planner, and send finalized layouts to the CAD/drafting team via Vectorworks. Claude Code will integrate this into the existing production Sales Hub.

**What Claude Code already has access to:**
- The full Sales Hub codebase (`bpt-sales-app`) — React/Vite, Azure Functions, Dataverse, HubSpot, SharePoint integrations
- The `bpt-vw-integration` repo with planning docs (VW-11, VW-13, KP-Response, etc.)
- The build spec compiled on 2026-04-21 (Sections 0–15)

**What Claude Code does NOT have:**
- The planner component source code (`SalesLayoutPlanner_V5.3.jsx`)
- The structured furniture catalog data
- The tent validation rule sets in code-ready form
- The layout generation rules (`bp_layout_generator.py` logic)
- The seat templates (`seat_templates.json`)
- The Claude system prompt for layout generation
- Google Maps / elevation API integration details

---

## Deliverables Needed

Return each deliverable as a clearly labeled section. Use code fences for all code/JSON/data. No prose summaries — Claude Code needs implementation-ready artifacts.

---

### DELIVERABLE 1: Planner Component (`SalesLayoutPlanner.jsx`)

The complete `SalesLayoutPlanner_V5.3.jsx` source, modified for embedding in a React app:

**Required changes from the artifact/standalone version:**
- Remove ALL CDN dependencies (Tailwind CDN, external font links, etc.). All styling must be inline or in a companion CSS file.
- Remove any `window.storage`, `localStorage`, or Claude.ai artifact sandbox patterns.
- Remove any `window.open()` file download triggers — exports go through the parent via callback.
- Accept these props:
  ```jsx
  {
    initialLayout: Object,           // VW-13 v1.1 JSON — hydrate state from this on mount
    jobId: String,                   // cr55d_jobid
    readOnly: Boolean,               // disable all interactive handlers when true
    onLayoutChange: Function,        // (layoutJSON) => void — fires on every committed change
  }
  ```
- Fire `onLayoutChange(currentJSON)` after every committed state change (add/remove/move/resize/edit tent or furniture). The parent will debounce before persisting.
- Hydrate internal state from `initialLayout` on mount and when `initialLayout` changes (new layout from Claude generation).
- Must render correctly inside a container div at any width from 600px to 1400px (Sales Hub quote builder pane is ~58% of viewport).
- Keep the AI chat assistant interface BUT route it through a `onAIRequest: (messages) => Promise<string>` prop instead of calling Claude directly — the parent Sales Hub will proxy through its existing `/api/claude-proxy`.
- If there's a companion CSS file, include it. If styles are inline, that's fine too.

**Return:** The full JSX file (or files if split into sub-components). Do not truncate.

---

### DELIVERABLE 2: Furniture Catalog (`furnitureCatalog.json`)

The complete VW-15 catalog as a JSON array. Every item needs:

```json
{
  "symbol": "Table - Round - 60in - 10 Seat",
  "category": "Table",
  "shape": "round",
  "width_mm": 1524,
  "height_mm": 1524,
  "seats": 10,
  "oriented": false,
  "insertion_point": "center",
  "notes": ""
}
```

For oriented items (Sweetheart, Head Table, Bar, Lounge Set), include:
- `"oriented": true`
- `"insertion_point"` description (e.g., `"center_back_edge"` for Lounge Set)
- `"open_face_direction"` at rotation 0 (e.g., `"-Y"`)

For Custom types (Stage, Dance Floor, Service Table), include:
- `"type": "Custom"`
- `"default_width_mm"` and `"default_height_mm"`

**Return:** Complete JSON array of all 34 items.

---

### DELIVERABLE 3: Tent Validation Rules (`tentValidation.js`)

A JavaScript module that exports validation functions. For each of the 7 tent types, define:

```js
export const TENT_CONFIGS = {
  Structure: {
    series: {
      G: { bay_spacing: 3000, widths: ['3m', '6m', '9m', '12m', '15m'] },
      M: { bay_spacing: 5000, widths: ['15m', '20m', '25m'] },
      L: { bay_spacing: 5000, widths: ['30m', '35m'] }
    },
    leg_heights: ['3m', '3.4m', '4m'],
    default_leg_height: '3.4m',
    wall_types: ['fabric', 'glass', 'railing', 'open'],
    gable_presets: ['full', 'open_center', 'none']
  },
  Arcum: { /* same as Structure */ },
  Atrium: {
    variants: [
      { name: 'Black A-Frame', widths: ['15m', '21m'], bay_spacings: [3000, 5000], has_interior_baseplates: true },
      // ... all 4 variants
    ],
    default_variant: 'Black A-Frame',
    default_width: '15m'
  },
  Sailcloth: {
    sizes: [20, 32, 44, 59, 66, 81],
    // length formula, center pole rules, etc.
  },
  Century: { /* ... */ },
  Navitrack: {
    // Closed spec — exact configs only
    configs: [
      { width: '15ft', end_depth: '7.5ft', end_leg_spacing: null, mid_spacings: ['10ft', '15ft'] },
      // ... all 4
    ]
  },
  Marquee: {
    widths: ['6ft', '9ft'],
    default_width: '9ft',
    length_increment: '10ft',
    connector_rules: { /* Structure↔Structure, Pole↔Pole, etc. */ }
  }
}

export function validateTent(tent) {
  // Returns { valid: boolean, errors: string[], warnings: string[] }
}

export function validateLayout(layoutJSON) {
  // Validates entire layout — all tents + furniture references
}
```

**Return:** Complete JS module with all 7 types fully specified plus validation functions.

---

### DELIVERABLE 4: Layout Generation Rules (`layoutRules.js`)

The zone-based furniture placement logic from `bp_layout_generator.py`, translated to JavaScript:

- Zone definitions (focal zone, seating zones N/S/E/W, bar zone, etc.)
- Table count distribution per zone based on guest count
- Symmetry enforcement (bilateral about ridge)
- Collision detection algorithm
- Structural exclusion zones (center poles, baseplates)
- MCC (minimum center-to-center) spacing rules
- Organic jitter (±150mm)
- Stage/dance floor/bar placement priority rules

```js
export function generateFurnitureLayout(tent, guestCount, eventType, preferences) {
  // Returns furniture array matching VW-13 schema
}
```

**Return:** Complete JS module. Include the heatmap-derived zone proportions if available.

---

### DELIVERABLE 5: Seat Templates (`seatTemplates.json`)

The `seat_templates.json` file — exact chair positions per table symbol for collision detection and visual rendering.

```json
{
  "Table - Round - 60in - 10 Seat": {
    "chairs": [
      { "x_mm": 0, "y_mm": 950, "rotation": 0 },
      // ... all 10 positions
    ],
    "chair_width_mm": 450,
    "chair_depth_mm": 450
  }
}
```

**Return:** Complete JSON for all table symbols that have chairs.

---

### DELIVERABLE 6: Claude System Prompt for Layout Generation

The system prompt that will be stored in `cr55d_aiinstructions` (Dataverse) with key `layout_generator`. This prompt teaches Claude:

1. The VW-13 JSON schema with defaults-first philosophy
2. All 7 tent type configurations and constraints
3. The furniture catalog with placement rules
4. Sales-language translations (e.g., "tall" → `leg_height: "4m"`)
5. Zone-based layout generation strategy
6. Collision/exclusion zone awareness
7. Symmetry and organic offset rules

The prompt should instruct Claude to return ONLY valid JSON (no markdown fencing, no commentary) matching the VW-13 v1.1 schema.

**Return:** The complete system prompt text.

---

### DELIVERABLE 7: Google Maps / Elevation API Integration

Specs for the venue site data integration:

1. **What API(s)** are being used (Google Maps JavaScript API, Elevation API, Geocoding API, etc.)
2. **What data** is pulled (satellite imagery, elevation profile, parcel boundaries, etc.)
3. **How it integrates** with the planner (background layer? elevation constraints? site boundary overlay?)
4. **API key requirements** and quota expectations
5. **Any existing code** for the Maps integration

If this isn't built yet, provide the planned spec so we can stub the integration points.

**Return:** Integration spec and/or code.

---

### DELIVERABLE 8: Component Dependencies

List every npm package the planner component requires beyond React itself:

```json
{
  "dependencies": {
    "package-name": "^version"
  }
}
```

Flag any packages that are currently loaded via CDN that need to be converted to npm imports.

**Return:** Package list with versions.

---

## Format Requirements

- Each deliverable should be clearly labeled (`## DELIVERABLE 1`, etc.)
- Code/JSON in fenced code blocks with language tags
- No truncation — Claude Code needs complete files, not snippets
- If a deliverable is too large for a single response, split it with clear part labels (`DELIVERABLE 1 — Part 1 of 3`)
- If something doesn't exist yet or is still in progress, say so explicitly rather than generating placeholder content

## Priority Order

If you need to prioritize (e.g., context limits):
1. Deliverable 1 (Planner component) — biggest and most critical
2. Deliverable 3 (Tent validation) — needed for JSON validation
3. Deliverable 2 (Furniture catalog) — needed for planner + generation
4. Deliverable 6 (Claude prompt) — needed for auto-generation
5. Deliverable 4 (Layout rules) — needed for generation quality
6. Deliverable 5 (Seat templates) — needed for collision detection
7. Deliverable 7 (Google Maps) — can be stubbed initially
8. Deliverable 8 (Dependencies) — quick but needed for build
