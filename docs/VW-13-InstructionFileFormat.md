# VW-13 Instruction File Format
## Vectorworks 2026 | Blue Peak Tents | Specification Document

---

## Overview

This document defines the format of the `.md` instruction file — the bridge between the sales intake system and the Vectorworks plugin. The file is produced by Claude (via the sales intake interface) and consumed by the VW **Load Job** plugin command.

Every instruction file contains two sections: a human-readable audit brief (Section 1) and a machine-readable JSON data block (Section 2). A future Section 3 will support furniture layout specifications.

---

## File Lifecycle

1. **Created** — Claude generates the file during sales intake conversation
2. **Queued** — File is deposited in the shared Queue folder on SharePoint
3. **Reviewed** — Sales rep reviews Claude's plain-language summary before export (approval happens inside the conversation, not on the file)
4. **Picked up** — CAD operator runs Load Job plugin, browses to Queue folder, selects file
5. **Linked** — Plugin parses the file and links it to the active VW project
6. **Archived** — File moves from Queue to the job folder in the Jobs SharePoint library

Sales can freely edit or regenerate the file while it remains in the Queue. Once the CAD operator links it, the file is considered consumed.

---

## File Naming

```
{UID}-instruction.md
```

The UID is the job ID from `cr55d_jobs` in Dataverse. It appears in the filename and in the file header. The Load Job plugin matches files by UID value.

Examples:
```
BPT-2026-0142-instruction.md
BPT-2026-0143-instruction.md
```

---

## File Structure

The file has two major sections separated by a horizontal rule delimiter (`---`). A JSON code fence in Section 2 contains all machine-readable data.

```
# Section 1 — Job Brief
(human-readable markdown)

---

# Section 2 — Placement Data
```json
{
  (machine-readable JSON)
}
`` `
```

The VW plugin identifies Section 2 by locating the JSON code fence (` ```json `) and parsing everything between the opening and closing fences.

---

## Section 1 — Job Brief

**Purpose:** Human-readable audit document for the CAD operator. Sales reps do not review this section — their approval happens inside the Claude conversation before the file is generated.

**Format:** Standard markdown. No rigid schema. Claude writes this as a clear summary of what was discussed.

### Required Fields

| Field | Description |
|---|---|
| Job UID | Project identifier from `cr55d_jobs` |
| Client Name | Client or customer name |
| Event Name | Name of the event |
| Event Date | Scheduled date(s) |
| Venue | Venue name and location |
| Contact | Sales rep who created the request |
| Created | Date and time the file was generated |

### Tent Summary Table

Section 1 includes a plain-language table summarizing each tent in the job. This is for the operator's quick reference — not parsed by the plugin.

Example:

```markdown
# Job Brief

| Field | Value |
|---|---|
| Job UID | BPT-2026-0142 |
| Client | Meridian Events |
| Event | Thompson-Garcia Wedding Reception |
| Date | June 14, 2026 |
| Venue | Cantigny Park, Wheaton IL |
| Contact | Sarah M. |
| Created | 2026-04-02 14:30 CST |

## Tents

| # | Type | Size | Bays | Notes |
|---|---|---|---|---|
| 1 | Structure | 6m wide, 4 bays @ 3000mm | 4 | Glass south side, fabric other 3 |
| 2 | Structure | 3m wide, 2 bays @ 3000mm | 2 | Catering staging, no walls |
```

---

## Section 2 — Placement Data

**Purpose:** Machine-readable JSON consumed by the VW Load Job plugin. This section contains every parameter needed to call the appropriate tent placement command.

**Format:** JSON inside a fenced code block. The plugin extracts this block and parses it with Python's `json.loads()`.

### Top-Level Schema

```json
{
  "version": "1.0",
  "uid": "BPT-2026-0142",
  "created": "2026-04-02T14:30:00-06:00",
  "tents": [
    { ... },
    { ... }
  ]
}
```

| Key | Type | Required | Description |
|---|---|---|---|
| `version` | string | Yes | Format version. Current: `"1.0"` |
| `uid` | string | Yes | Job UID from `cr55d_jobs`. Must match filename. |
| `created` | string | Yes | ISO 8601 timestamp of file generation |
| `tents` | array | Yes | Array of tent configuration objects |

### Tent Object Schema

Each object in the `tents` array defines one tent to be placed.

```json
{
  "id": 1,
  "type": "Structure",
  "width": "6m",
  "bay_spacing_mm": 3000,
  "bays": 4,
  "label": "Main Reception Tent",
  "placement": "interactive",
  "rotation": 0,
  "components_3d": {
    "gable_frame": true,
    "roof": true,
    "purlins": true,
    "eave_bar": true,
    "gable_fabric": true,
    "gable_upright": true,
    "gable_walls": true,
    "walls": {
      "north": { "type": "fabric", "per_bay": false },
      "south": { "type": "glass", "per_bay": false },
      "east": { "type": "fabric", "per_bay": false },
      "west": { "type": "fabric", "per_bay": false }
    }
  },
  "components_2d": {
    "footprint": true,
    "baseplates": true,
    "ridge_line": true,
    "roof_line": true
  }
}
```

### Tent Object Fields

#### Core Parameters

| Key | Type | Required | Description |
|---|---|---|---|
| `id` | integer | Yes | Sequential identifier within this file (1, 2, 3...) |
| `type` | string | Yes | Tent style. Values: `"Structure"`, `"Arcum"`, `"Sailcloth"`, `"Century"`, `"Atrium"`, `"Navitrack"` |
| `width` | string | Yes | Gable width. e.g. `"3m"`, `"6m"`, `"15m"` |
| `bay_spacing_mm` | integer | Yes | Bay spacing in millimeters. Values: `3000` or `5000` |
| `bays` | integer | Yes | Number of bays |
| `label` | string | No | Human-readable tent description for operator review dialog |
| `placement` | string | No | `"interactive"` (click-place, default) or `"coordinates"` (auto-place at specified x,y) |
| `rotation` | number | No | Rotation angle in degrees. Default: `0` |
| `x` | number | No | X coordinate for auto-placement. Required if `placement` is `"coordinates"` |
| `y` | number | No | Y coordinate for auto-placement. Required if `placement` is `"coordinates"` |

#### 3D Components (`components_3d`)

All boolean. Default: `true`. These are the standard configuration — Claude only needs to include fields that differ from default.

| Key | Type | Default | Description |
|---|---|---|---|
| `gable_frame` | boolean | `true` | Structural frame at each bay position |
| `roof` | boolean | `true` | Roof panels per bay |
| `purlins` | boolean | `true` | Purlins per bay |
| `eave_bar` | boolean | `true` | Eave bars at start and end |
| `gable_fabric` | boolean | `true` | Gable roof fabric at start and end |
| `gable_upright` | boolean | `true` | Gable upright at start and end |
| `gable_walls` | boolean | `true` | Gable wall assemblies at start and end |
| `walls` | object | see below | Per-side wall configuration |

#### Wall Configuration (`components_3d.walls`)

Walls are configured per-side using compass directions. Each side has a type and an optional per-bay override array.

| Key | Type | Default | Description |
|---|---|---|---|
| `north` | object | `{ "type": "fabric" }` | North side wall configuration |
| `south` | object | `{ "type": "fabric" }` | South side wall configuration |
| `east` | object | `{ "type": "fabric" }` | East gable wall configuration |
| `west` | object | `{ "type": "fabric" }` | West gable wall configuration |

**Wall side object:**

| Key | Type | Default | Description |
|---|---|---|---|
| `type` | string | `"fabric"` | Wall type for the entire side. Values: `"fabric"`, `"glass"`, `"railing"`, `"open"` |
| `per_bay` | boolean | `false` | If `true`, the `bay_overrides` array specifies individual bay wall types |
| `bay_overrides` | array | `[]` | Array of wall types per bay (bay 1 to bay N). Only read if `per_bay` is `true` |

**Standard configuration (default):** All four sides are `"fabric"` with `per_bay: false`. Claude only specifies wall details when the sales rep requests something different from the standard.

**Example — glass on south, open bays 3-4 on north:**

```json
"walls": {
  "north": {
    "type": "fabric",
    "per_bay": true,
    "bay_overrides": ["fabric", "fabric", "open", "open"]
  },
  "south": { "type": "glass" },
  "east": { "type": "fabric" },
  "west": { "type": "fabric" }
}
```

#### 2D Components (`components_2d`)

All boolean. Default: `true`.

| Key | Type | Default | Description |
|---|---|---|---|
| `footprint` | boolean | `true` | Outer boundary rectangle |
| `baseplates` | boolean | `true` | 305mm baseplate squares at frame positions |
| `ridge_line` | boolean | `true` | Center ridge line |
| `roof_line` | boolean | `true` | Roof pitch indicators at each end |

---

## Defaults-First Design

The instruction file follows a **defaults-first** philosophy. Every tent has a standard configuration that represents the most common setup:

- All frame components on
- Fabric walls on all four sides (uniform, not per-bay)
- All 2D components on
- Interactive placement (operator clicks to place)
- 0 degree rotation

Claude only includes fields that differ from these defaults. A minimal tent spec for a standard tent is:

```json
{
  "id": 1,
  "type": "Structure",
  "width": "6m",
  "bay_spacing_mm": 3000,
  "bays": 4
}
```

This produces a complete standard Structure tent. All components default to on, all walls default to fabric. The plugin fills in every missing field from the default configuration.

---

## Plugin Parsing Logic

The VW Load Job plugin processes the file as follows:

1. Read the entire `.md` file as text
2. Split on the `---` delimiter to separate Section 1 from Section 2
3. Locate the JSON code fence (` ```json ` to ` ``` `)
4. Extract the JSON string and parse with `json.loads()`
5. Validate the `version` field
6. Loop through the `tents` array
7. For each tent:
   a. Display a confirmation dialog showing all parameters (label, type, width, bays, wall config)
   b. Operator confirms or skips
   c. On confirm: determine placement command by `type` field
   d. Apply defaults for any missing fields
   e. Call the appropriate `generate_tent()` variant with parsed parameters
   f. If `placement` is `"interactive"`: activate click-placement
   g. If `placement` is `"coordinates"`: place at specified `x`, `y` with `rotation`

### Symbol Name Resolution

The plugin builds symbol names from the tent parameters using the naming convention:

```
[Type] - [bay_spacing_mm]mm - [width] - [Component]
```

Example: A Structure tent with `width: "6m"` and `bay_spacing_mm: 3000` resolves to prefix:
```
Structure - 3000mm - 6m -
```

Which produces symbol lookups like:
```
Structure - 3000mm - 6m - Gable Frame
Structure - 3000mm - 6m - Roof
Structure - 3000mm - 6m - Side Walls
```

**Note:** This naming convention reflects the Phase 0 rename. Current symbols use the old `G Series - 3m Bay - 6m - Gable Frame` pattern. The prefix builder in the plugin must be updated as part of Phase 0.4.

---

## Validation Rules

The plugin should validate the following before attempting placement:

| Rule | Action on Failure |
|---|---|
| `version` is recognized | Alert operator, abort |
| `uid` matches expected job | Warn operator, allow override |
| `type` is a known tent style | Skip tent, alert operator |
| `width` is valid for the `type` | Skip tent, alert operator |
| `bay_spacing_mm` is valid for the `width` (3000 or 5000 per series rules) | Skip tent, alert operator |
| `bays` is a positive integer | Skip tent, alert operator |
| All referenced symbols exist in the drawing | Skip tent, alert operator with missing symbol names |
| `bay_overrides` length matches `bays` count when `per_bay` is `true` | Warn operator, fall back to uniform type |

The plugin should never crash on malformed data. Every failure mode should produce a clear dialog message and allow the operator to continue with the remaining tents.

---

## Section 3 — Furniture Layout (Future — Phase 4)

**Not yet defined.** When implemented, Section 3 will contain:

- Furniture specifications per tent (event type, guest count, table style)
- Claude API-generated layout positions (symbol name, x, y, rotation per piece)
- Placed inside the bounds of a specific tent from the `tents` array (referenced by `id`)

Section 3 will be added to the file format as a separate JSON block below Section 2, maintaining backward compatibility — files without Section 3 continue to work exactly as before.

---

## Complete Example File

```markdown
# Job Brief

| Field | Value |
|---|---|
| Job UID | BPT-2026-0142 |
| Client | Meridian Events |
| Event | Thompson-Garcia Wedding Reception |
| Date | June 14, 2026 |
| Venue | Cantigny Park, Wheaton IL |
| Contact | Sarah M. |
| Created | 2026-04-02 14:30 CST |

## Tents

| # | Type | Size | Bays | Notes |
|---|---|---|---|---|
| 1 | Structure | 6m wide, 4 bays @ 3000mm | 4 | Glass south side, fabric other 3 sides |
| 2 | Structure | 3m wide, 2 bays @ 3000mm | 2 | Catering staging, no walls |

## Notes

Client prefers the main tent oriented with the gable facing the parking lot (east).
Catering tent positioned 5m north of the main tent.

---

# Placement Data

```json
{
  "version": "1.0",
  "uid": "BPT-2026-0142",
  "created": "2026-04-02T14:30:00-06:00",
  "tents": [
    {
      "id": 1,
      "type": "Structure",
      "width": "6m",
      "bay_spacing_mm": 3000,
      "bays": 4,
      "label": "Main Reception Tent - 6m x 12m",
      "components_3d": {
        "walls": {
          "north": { "type": "fabric" },
          "south": { "type": "glass" },
          "east": { "type": "fabric" },
          "west": { "type": "fabric" }
        }
      }
    },
    {
      "id": 2,
      "type": "Structure",
      "width": "3m",
      "bay_spacing_mm": 3000,
      "bays": 2,
      "label": "Catering Staging Tent - 3m x 6m",
      "components_3d": {
        "walls": {
          "north": { "type": "open" },
          "south": { "type": "open" },
          "east": { "type": "open" },
          "west": { "type": "open" }
        }
      },
      "components_2d": {
        "baseplates": false
      }
    }
  ]
}
`` `
```

---

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-04-02 | Initial specification |
