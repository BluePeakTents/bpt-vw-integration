# VW-11 Build Plan — Vectorworks + Claude Integration
## Blue Peak Tents | Construction Roadmap

**KP Review: 2026-04-02**

> **KP NOTE (General):** Jon, this is solid work. The phased approach and dependency thinking are exactly right. I'm layering in comments throughout with specifics on what exists in our IT systems, what doesn't yet, and questions I need answered to plan my side of the work. Anywhere you see `[KP]` is a comment from me. Read through all of them and bring back your responses so we can lock down the plan.

---

## Purpose

This document defines the build order for the Vectorworks + Claude API integration system. The sequence minimizes rework: each phase builds on the last without requiring changes to completed work.

---

## Architecture Summary

**Hybrid system:** Sales-side Claude Project produces .md instruction files. VW plugin parses them directly for standard tent placement. Claude API called from within VW for smart features (furniture auto-layout, image-to-coordinates, mid-workflow adjustments).

> **[KP - Sales Intake Architecture]:** I want to explore this more before you build the Claude Project for sales intake. See my detailed comments in the IT Requirements doc, but the short version: a custom UI inside one of our existing apps (calling Claude API through our existing proxy) might be a better long-term fit than giving sales reps access to a shared Claude.ai Project. I don't want to block your Phase 0-1 work, but don't invest heavily in the Claude Project setup until we align on this. I have specific questions for you in the IT Requirements review.

**Two knowledge domains:** Business knowledge from Dataverse defines what the client needs (capacity, inventory, accessories, layout standards). Modeling knowledge from custom CAD instruction documents is the translation layer that converts sales language into exact model-space components (symbol names, parameters, coordinates, assembly logic). Digital models built to ideal measurements, not constrained by inventory.

> **[KP - Business Knowledge / Dataverse]:** The knowledge domain separation is the right call. On the Dataverse side, here's the current reality of what exists vs. what you're asking for. See detailed table below in Phase 3 comments.

**Universal naming convention:** `[Type] - [Identifiers] - [Component]` for all tents and furniture. Structure tents use `Structure - [bay spacing mm] - [width] - [component]`. Series letters (G/M/L) dropped.

**Project linkage:** The .md instruction file and VW project file are linked by a UID from Blue Peak's IT-managed ID system. The same UID is referenced across QuickBooks, HubSpot, and other organizational systems. The UID can appear anywhere in either filename; the system matches on the UID value, not on filename pattern.

> **[KP - UID / Project Linkage]:** This is the job ID from our `cr55d_jobs` Dataverse table. Every job gets one at quote creation and it follows the job through the full lifecycle. The field you'll reference is `cr55d_jobid` (or the record GUID). Other fields on the job record that may be useful to you:
> - `cr55d_eventname` - event name
> - `cr55d_clientname` - client/customer
> - `cr55d_eventdate` - event date
> - `cr55d_venue` - venue name
> - `cr55d_planner` - planner name
> - `cr55d_salesfolderuri` - Graph item ID pointing to the job's Sales folder in SharePoint
> - `cr55d_productionfolderuri` - Graph item ID pointing to the job's Production folder in SharePoint
>
> No new UID system needed. You're consuming what already exists. The question is just how the sales rep surfaces the job ID to your system (manual entry is fine for v1).

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

> **[KP - Translation Dictionary / Existing Data]:** We already have some of this mapping in Dataverse. Specifically:
> - **`cr55d_bomrules`** - Bill of Materials rules that map tent systems to their components. Fields include `cr55d_tentsystem`, `cr55d_moduletype`, `cr55d_modulesize`, `cr55d_componentname`, `cr55d_quantity`, `cr55d_componentcategory`. This might overlap with or feed into your translation dictionary.
> - **`cr55d_skurules`** (336 records) - SKU substitution logic with `cr55d_coreitems`, `cr55d_commonitems`, `cr55d_ruleconfidence`.
>
> **Question:** Have you looked at the BOM rules data? I want to understand whether your translation dictionary is a superset of what's in `cr55d_bomrules` or a different thing entirely. If there's overlap, we should make sure they don't drift apart.

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

> **[KP]:** Phase 0 is entirely your domain. No IT blockers. Go.

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

> **[KP - File Format]:** Strong preference for embedded JSON over YAML or structured markdown for Section 2. JSON is what every other BPT system speaks (Dataverse API, our Azure Functions, QBO queries). Keeping it consistent means less translation if we ever want to generate these files programmatically from our side.

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

> **[KP]:** Phase 1 is also entirely your domain. No IT blockers. The only thing I'd ask is that when you finalize the .md file format (1.1), send me a copy of the spec so I can evaluate whether we'd ever want to generate these from our systems.

---

## Phase 2: Sales-Side Claude Project (No IT Dependency)

**Goal:** Sales team describes events to Claude and gets valid .md instruction files. Uses manually compiled business knowledge until Dataverse is connected.

> **[KP - Sales Intake: Big Picture Question]:** Before you build this, I need to understand the workflow you're envisioning more concretely. I have questions:
>
> 1. **Who is the user?** Is this the sales rep directly, or does the sales rep hand off to someone else who runs the Claude conversation?
> 2. **When in the sales process does this happen?** At initial quote? After the client confirms? Right before production handoff?
> 3. **What does the sales rep have in hand when they start?** Just a client request email? A completed quote? A job record in our system?
> 4. **How often does the output need revision?** Is this one-and-done, or does the sales rep iterate ("actually, change the south wall to fabric")?
> 5. **What happens to the .md file after it's generated?** Does someone review it before you pick it up, or does it just land in the shared folder?
> 6. **How many sales reps would use this?** We have a small team - is this 2-3 people or broader?
> 7. **Does the sales rep need to see the CAD output, or just trust it?** i.e., is there a feedback loop?
>
> **Why I'm asking:** If the answer is "2-3 sales reps fill in structured info from an existing job record and get a spec file," that's a form - not a freeform chat. A custom UI in our sales app or ops app (with Claude API behind it doing the translation) would give us:
> - No per-seat Claude.ai licensing
> - Controlled UX (dropdowns for tent types, validated inputs for dimensions)
> - Direct Dataverse integration (auto-pull job details, inventory, venue history)
> - Audit trail in our systems
> - The same Claude intelligence doing the translation, just called via API instead of chat
>
> I'm not saying no to the Claude Project approach - it might be the right prototyping tool. But I want your answers to these questions before we decide.

### 2.1 Create the Sales Intake Claude Project
- New shared Project in Blue Peak Claude.ai org account
- Load modeling knowledge: VW-02, VW-09, VW-10, VW-12, VW-13, and the translation dictionary from Phase 0.3

### 2.2 Compile Initial Business Knowledge
- Manually create BP-series .md files from available product knowledge
- BP-01-Inventory.md (tent styles, sizes)
- BP-02-Capacity-Guide.md (guest counts by event type)
- BP-03-Accessories.md (wall types, flooring, lighting)
- Load into the Claude Project

> **[KP - Existing Dataverse Data You Can Pull From]:** Before you manually compile these, here's what already exists in Dataverse that you could export:
>
> | Your BP File | Existing Dataverse Source | Notes |
> |---|---|---|
> | BP-01 Inventory (tent styles/sizes) | `cr55d_inventories` (992 records) | Category is a Picklist field with values like Structures, Anchoring & Walls, Doors & Glass, etc. Filterable. |
> | BP-01 (product catalog) | `cr55d_catalogskus` | Has `cr55d_sku`, `cr55d_description`, `cr55d_category`, `cr55d_subcategory`, `cr55d_unitprice` |
> | BP-02 Capacity Guide | **Does not exist** | No capacity/sqft-per-guest table in Dataverse today |
> | BP-03 Accessories | Partially in `cr55d_inventories` | Wall types, flooring, lighting are inventory categories but not structured as "what's compatible with what" |
> | Furniture catalog | Partially in `cr55d_inventories` | Category picklist value 306280009 = Furniture & Fencing. 992 records include furniture items but not layout dimensions. |
> | Layout standards | **Does not exist** | No spacing rules, ADA, fire code data in Dataverse |
> | Site requirements | **Does not exist** | No clearance/anchoring/power data in Dataverse |
> | Venue history | `cr55d_venuepatterns` (88 records) | Has `cr55d_venuename`, `cr55d_consistentskus`, `cr55d_totaljobs` - tells you what tents have historically gone to each venue |
> | BOM / components | `cr55d_bomrules` | Maps tent systems to components with quantities |
>
> **Question:** For the tables that don't exist yet (capacity guide, layout standards, site requirements), I need you to define exactly what data you need. Give me:
> - Table name (what would you call it)
> - Columns with data types (text, number, picklist, lookup)
> - Sample rows (3-5 examples of real data)
> - How often the data changes
> - Who maintains it (you? ops? sales?)
>
> I'm committed to building these into Dataverse properly, but I need the full picture before I design the schema. Don't give me an MVP - give me the complete requirement and I'll build it right the first time.

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

> **[KP]:** Phase 2 is where I need the most input from you before you proceed. Answer my questions above and we'll determine the right approach together. You can prototype with a Claude Project if it helps you validate the concept, but don't treat it as the production solution until we align.

---

## Phase 3: IT Integration (Requires IT Deliverables)

**Goal:** Connect Claude API to VW workstation and replace manual business knowledge with Dataverse data.

### 3.1 Receive IT Deliverables
- Claude API key deployed to workstation as environment variable
- Outbound HTTPS to api.anthropic.com confirmed
- Shared folder location confirmed with read/write access
- Dataverse access method determined (direct API or export)
- UID system access confirmed (manual entry or automated lookup)

> **[KP - IT Deliverables Status]:**
>
> | Deliverable | Status | Notes |
> |---|---|---|
> | Claude API key | **Ready when you need it.** We already have an `ANTHROPIC_API_KEY` provisioned. For v1, we'll use the existing key. I may split to a separate key later for usage tracking. |
> | Outbound HTTPS to api.anthropic.com | **Need to verify on your workstation.** Should be fine but I'll confirm. |
> | Shared folder | **Already exists.** See SharePoint section below. |
> | Dataverse access | **Two-phase approach.** Near-term: I'll export the relevant tables to .md files you can load into your Claude Project or reference from the API. Long-term: direct API access via our existing `dataverse-proxy` Azure Function (already built, handles OAuth automatically). |
> | UID / Job ID | **Already exists.** `cr55d_jobs` table. Sales rep provides the job ID manually for v1. |
>
> **API approach - near-term vs. long-term:**
> - **Near-term (Phase 3):** I give you the API key as an environment variable. Your VW plugin calls `api.anthropic.com` directly via `urllib.request`. Simple, no dependencies on our infrastructure.
> - **Long-term (maturity):** Your VW plugin calls our `claude-proxy` Azure Function (already built in bpt-ops-app) instead of calling Anthropic directly. This gives us centralized logging, usage tracking, and the ability to swap models without touching your plugin. Not required for v1 but worth designing for.
>
> **Question:** Does your VW Python environment support HTTPS with modern TLS? Any proxy/firewall on the CAD workstation that might block outbound calls? I need to test this before you hit Phase 3.

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

> **[KP - Dataverse Connection Detail]:** For the export approach, I can build a lightweight script that pulls the relevant tables and writes .md files on a schedule. Tables I'd export for you:
> - `cr55d_inventories` (filtered to active items, grouped by category)
> - `cr55d_catalogskus` (full product catalog)
> - `cr55d_bomrules` (component mappings)
> - `cr55d_venuepatterns` (venue history)
> - Plus whatever new tables we build from your capacity/layout/site requirements
>
> For direct API access, your Claude API calls could use tool_use (function calling) to query Dataverse in real-time. This is more powerful but more complex. Let's start with export and graduate to direct access when we see the limitations.

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

> **[KP - Furniture Data Gap]:** For this to work, Claude needs to know the physical dimensions of each furniture piece (table diameter, chair footprint, dance floor panel size). That data is NOT in `cr55d_inventories` today - we only track quantities and locations, not dimensions. This is one of the new tables I'd need to build.
>
> **Question:** Can you give me the full list of furniture attributes you'd need for auto-layout? At minimum I'm guessing: item name, category, length, width, height, footprint shape (round/rect), min clearance, stackable (for load planning). What else?

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

> **[KP]:** Phase 4 is ambitious and I like the vision. The image-to-coordinates feature (4.2) is a creative use of Claude's vision capability. Just be aware that coordinate precision from image interpretation will have tolerances - make sure the operator review step (4.1) is robust enough to catch layout issues before committing.

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

> **[KP - Dependency Map Addition]:** From IT's side, I can work in parallel with your Phase 0-1:
> - Verify network/firewall on CAD workstation
> - Prepare API key deployment
> - Build Dataverse export scripts for business knowledge tables
> - Design and build new Dataverse tables (capacity, layout standards, furniture dimensions) once you give me the requirements
>
> None of that blocks you. When you're ready for Phase 3, the IT deliverables should already be waiting.

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

---

## KP Summary - Action Items for Jon

1. **Answer the 7 sales intake questions** (in Phase 2 comments above) so we can decide Claude Project vs. custom UI
2. **Define new Dataverse table requirements** for capacity guide, layout standards, site requirements, and furniture dimensions. Give me table name, columns, data types, sample rows, change frequency, and who maintains it.
3. **Review existing Dataverse tables** (`cr55d_bomrules`, `cr55d_catalogskus`, `cr55d_venuepatterns`) and tell me how they relate to your translation dictionary - overlap, superset, or different thing?
4. **Use JSON for Section 2** of the .md instruction file format
5. **Send me the VW-13 spec** when you finalize the instruction file format
6. **Confirm your workstation's network** - can you hit external HTTPS endpoints from VW's Python environment today?
7. **Define furniture attributes needed** for auto-layout (dimensions, clearances, etc.)

No IT blockers on Phases 0-1. Go build. I'll work in parallel on the Dataverse and API preparation.
