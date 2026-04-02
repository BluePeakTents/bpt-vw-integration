# VW-11 Build Plan — Vectorworks + Claude Integration
## Blue Peak Tents | Construction Roadmap

---

## Purpose

This document defines the build order for the Vectorworks + Claude API integration system. The sequence minimizes rework: each phase builds on the last without requiring changes to completed work.

---

## Architecture Summary

**Hybrid system:** Sales-side Claude Project produces .md instruction files. VW plugin parses them directly for standard tent placement. Claude API called from within VW for smart features (furniture auto-layout, image-to-coordinates, mid-workflow adjustments).

**Two knowledge domains:** Business knowledge from Dataverse defines what the client needs (capacity, inventory, accessories, layout standards). Modeling knowledge from custom CAD instruction documents is the translation layer that converts sales language into exact model-space components (symbol names, parameters, coordinates, assembly logic). Digital models built to ideal measurements, not constrained by inventory.

**Universal naming convention:** `[Type] - [Identifiers] - [Component]` for all tents and furniture. Structure tents use `Structure - [bay spacing mm] - [width] - [component]`. Series letters (G/M/L) dropped.

**Project linkage:** The .md instruction file and VW project file are linked by a UID from Blue Peak's IT-managed ID system. The same UID is referenced across QuickBooks, HubSpot, and other organizational systems. The UID can appear anywhere in either filename; the system matches on the UID value, not on filename pattern.

---

## Phase 0: Foundation (No External Dependencies)

**Goal:** Establish the naming convention and component architecture that everything downstream depends on.

### 0.1 Define Complete Naming Convention
- Finalize the universal naming pattern for all tent styles
- Define furniture symbol categories and naming pattern
- Document the complete symbol name list for all existing tent components
- Document the complete symbol name list for all existing furniture

### 0.2 Redesign Component Granularity
- Define the new component breakdown for Structure tents:
  - Frame: baseplate assembly, upright leg assembly, roof beam assembly (per style), ridge connection
  - Roof: roof fabric panels (per bay), gable roof fabric (end caps)
  - Walls: fabric wall, glass wall, railing (per bay, per side, independently selectable)
  - Accessories: lattice trim, grid/flooring, gable wall assembly, scaffolding/sub-structure boxes
- Determine which components are unique per width and which are shared
- Determine insertion point logic for new granular components
- Document in new VW-12 Component Architecture

### 0.3 Build the Modeling Translation Dictionary
- Document how every sales-language request maps to model-space components
- Tent dimensions to series/width/bay count
- Leg height requests to specific upright symbols
- Directional wall requests (N/S/E/W) to per-side component placement
- Accessory names in sales language to symbol names in VW
- Implicit components (baseplates always present, roof beams always present, etc.)
- This dictionary is the core of the modeling knowledge domain

### 0.4 Rename Existing Symbols
- Rename all symbols in Structure Tents.vwx to new convention
- Old: `G Series - 3m Bay - 3m - Gable Frame`
- New: `Structure - 3000mm - 3m - Gable Frame`
- Update all Marionette networks that reference symbols by name
- Update the Place Structure Tent plugin script prefix builder
- Test that existing placed instances still resolve

### 0.5 Rename Furniture Symbols
- Audit all existing furniture symbols
- Apply the new convention
- Document the complete furniture symbol catalog

### 0.6 Update Project Documents
- Update VW-02 (Blue Peak Standards) with new naming convention
- Update VW-09 (G Series Progress) with new symbol names
- Update VW-10 (Place Structure Tent) with new prefix logic
- Create VW-12 (Component Architecture)

**Phase 0 Completion Criteria:** Every symbol follows the new convention. The translation dictionary is documented. Every project document reflects the new names. The Place Structure Tent command works with renamed symbols.

---

## Phase 1: Tent Placement Pipeline (No API, No IT Dependency)

**Goal:** A working system where a hand-written .md instruction file produces placed tents in Vectorworks. This is the fallback that works even if the API is never connected.

### 1.1 Define the .md Instruction File Format
- Design Section 1: human-readable job brief in business language (client, event, UID, tent list with plain descriptions)
- Design Section 2: machine-readable placement data in model-space language (symbol parameters, component toggles, per-bay/per-side configurations)
- Define the delimiter between sections
- Define the data format for Section 2 (embedded JSON, YAML, or structured markdown)
- Define where the UID appears (header metadata)
- Document in new VW-13 Instruction File Format

### 1.2 Build Test .md Files by Hand
- Sample 1: simple job, one Structure tent, test UID
- Sample 2: multi-tent job, 3 tents, mixed configurations, per-side wall variations
- Validate Section 2 contains all parameters generate_tent() needs

### 1.3 Solve Click-Placement
- Research alternatives to vs.GetPt() in plugin command context
- Test vs.GetPtL(), vs.CallTool(), or two-phase approach
- Document working solution in VW-09
- Primary technical blocker for interactive placement

### 1.4 Build the "Load Job" Menu Command
- New plugin command via Tools > Plug-in Manager
- Opens file browser dialog pointed at the shared folder
- Reads selected .md file, extracts UID
- Parses Section 2 into a list of tent configurations
- For each tent: displays confirmation dialog with all specs
- On confirm: activates click-placement
- Routes to appropriate placement command (Place Structure Tent, etc.)
- Calls generate_tent() at clicked coordinates with parsed parameters
- Loops for each tent in the job

### 1.5 Rebuild generate_tent() for New Component Granularity
- Refactor to support per-bay, per-side wall selection (fabric/glass/railing/open)
- Roof beam style selection
- Lattice, grid, gable, scaffolding toggles
- Leg height as a parameter (maps to upright symbol variant)
- Ensure all parameters represented in .md file format

### 1.6 Build Remaining Symbol Sets
- Build symbols for all Structure tent widths using new convention
- Calibrate offset values for each width
- Document in VW-14 Calibration Table

### 1.7 Test End-to-End
- .md file to Load Job to review dialog to click-place to verify geometry
- Test single tent, multi-tent, mixed configurations, per-side walls
- Test missing symbols (fail gracefully, not crash)

**Phase 1 Completion Criteria:** Hand-written .md files produce correctly placed tents with all component options. No API or IT involvement required.

---

## Phase 2: Sales-Side Claude Project (No IT Dependency)

**Goal:** Sales team describes events to Claude and gets valid .md instruction files. Uses manually compiled business knowledge until Dataverse is connected.

### 2.1 Create the Sales Intake Claude Project
- New shared Project in Blue Peak Claude.ai org account
- Load modeling knowledge: VW-02, VW-09, VW-10, VW-12, VW-13, and the translation dictionary from Phase 0.3

### 2.2 Compile Initial Business Knowledge
- Manually create BP-series .md files from available product knowledge
- BP-01-Inventory.md (tent styles, sizes)
- BP-02-Capacity-Guide.md (guest counts by event type)
- BP-03-Accessories.md (wall types, flooring, lighting)
- Load into the Claude Project

### 2.3 Write the Sales Intake System Prompt
- Claude's role: Blue Peak tent specification assistant
- Require the project UID at the start of every intake conversation
- Ask clarifying questions (guest count, event type, venue constraints, wall preferences per side)
- Always output in .md instruction file format (VW-13)
- Use the translation dictionary to convert business language to model-space parameters
- Validate against product rules (valid widths per bay spacing, component availability)

### 2.4 Test with Sample Sales Requests
- "6m x 18m Arcum on 3.5m legs, glass on the south side, seating for 120"
- "Two Structure tents connected with a gutter, one for ceremony, one for reception"
- "Small staging tent for catering, no walls, minimal setup"
- Verify Claude produces valid .md files with correct UIDs that parse in VW

### 2.5 Sales Team Testing
- Real sales rep, real upcoming event
- Feedback on question flow and output quality
- Iterate on system prompt

**Phase 2 Completion Criteria:** Sales team produces valid .md instruction files through Claude, tagged with UIDs. Files parse correctly in VW and produce correct geometry.

---

## Phase 3: IT Integration (Requires IT Deliverables)

**Goal:** Connect Claude API to VW workstation and replace manual business knowledge with Dataverse data.

### 3.1 Receive IT Deliverables
- Claude API key deployed to workstation as environment variable
- Outbound HTTPS to api.anthropic.com confirmed
- Shared folder location confirmed with read/write access
- Dataverse access method determined (direct API or export)
- UID system access confirmed (manual entry or automated lookup)

### 3.2 Test Claude API from Inside VW
- Test script: Claude API call via urllib.request with real API key
- Verify request/response from within VW plugin command
- Measure response time
- Document in VW-15 (API Integration Reference)

### 3.3 Build the VW API Call Function
- Reusable Python function: send prompt, receive structured response
- System prompt includes modeling knowledge for valid responses
- Error handling: timeout, invalid response, API errors
- API key from environment variable

### 3.4 Connect Dataverse Business Knowledge
- Direct API or exported .md files into Claude Project
- Replace manually compiled BP-series files with real data
- Test improved sales intake quality

### 3.5 Test Full Pipeline
- Real job, real UID, real Dataverse product data
- Sales to .md to VW placement
- Verify complete loop

**Phase 3 Completion Criteria:** Claude API callable from VW. Business knowledge from Dataverse. Full pipeline with real data and UIDs.

---

## Phase 4: Smart Features (API-Dependent)

**Goal:** Claude actively assists during drawing with furniture layouts, image interpretation, and mid-workflow intelligence.

### 4.1 Furniture Auto-Layout
- VW function calls Claude API with: tent interior bounds, event type, guest count
- Claude uses Dataverse layout standards to calculate positions
- Returns array: symbol name, (x, y), rotation angle per furniture piece
- VW places furniture symbols via vs.Symbol()
- Operator reviews before committing
- .md instruction file Section 3: furniture layout specs

### 4.2 Image-to-Coordinates
- VW exports screenshot of current drawing view
- Sends to Claude API as base64
- Claude identifies marked positions or reference points
- Returns coordinates mapped to VW coordinate system
- Define marker convention and scale communication method

### 4.3 Mid-Workflow Adjustments
- "Ask Claude" dialog during placement workflow
- Operator types instructions: "Add glass walls to bays 3 and 4 on south side"
- Claude interprets against current state, returns modified parameters
- VW executes modifications

### 4.4 Non-Structure Tent Commands
- Placement commands for: Sailcloth, Century, Arcum, Atrium, Navitrack
- Same pattern: .md file, confirmation dialog, click-place
- Define component breakdowns per style
- Build symbol sets as needed

**Phase 4 Completion Criteria:** Furniture auto-layout works. Image-to-coordinate placement works. Mid-workflow Claude interaction available. All tent styles have placement commands.

---

## Dependency Map

```
Phase 0 (Foundation) --- required by everything
    |
    +-- Phase 1 (Tent Placement) --- no external dependency
    |       |
    |       +-- Phase 2 (Sales Project) --- no external dependency
    |       |       |
    |       |       +-- Phase 3 (IT Integration) --- requires IT deliverables
    |       |               |
    |       |               +-- Phase 4 (Smart Features) --- requires API + Dataverse
    |       |
    |       +-- Phase 4.4 (Other Tent Styles) --- parallel with Phase 2-3
```

---

## Documents Created or Updated

| Document | Phase | Purpose |
|---|---|---|
| VW-02 (updated) | 0 | New naming convention |
| VW-09 (updated) | 0, 1 | New symbol names, click-placement solution |
| VW-10 (updated) | 0, 1 | New prefix logic, refactored generate_tent() |
| VW-12 (new) | 0 | Component Architecture: granular breakdown |
| Translation Dictionary (in VW-12 or standalone) | 0 | Sales language to model-space mapping |
| VW-13 (new) | 1 | Instruction File Format: .md spec with UID |
| VW-14 (new) | 1 | Calibration Table: offset values per width |
| VW-15 (new) | 3 | API Integration Reference |
| BP-01 through BP-05 | 2 | Business knowledge reference files |

---

## Current State

### Completed (Proof of Concept)
- Place Structure Tent menu command: working
- G Series 3m Bay 3m symbol set: 8 symbols complete
- G Series 3m Bay 6m symbol set: 9 symbols complete
- Marionette smart objects for 3m and 6m: working
- VW Layout Manager dialog system: confirmed
- HTTP from VW Python (urllib.request): confirmed
- Class structure (Tent_3D_*, Tent_2D_Plan): in use
- 2D plan generation: working

### Must Be Rebuilt in Phase 0-1
- All symbol names (rename to new convention)
- Place Structure Tent script (new prefix, new granularity)
- Marionette networks (may deprecate in favor of plugin commands)
- Offset/calibration values (re-verify after rename)

### Not Yet Started
- Translation dictionary (sales language to model-space)
- Component granularity redesign
- Click-placement solution
- .md instruction file format
- Load Job menu command
- Sales-side Claude Project
- Claude API integration in VW
- Furniture auto-layout
- Image-to-coordinates
- Non-Structure tent commands
- UID integration with IT system
