# KP Response: Sales App Integration Workflow Proposal
## April 15, 2026

Jon, this is the right direction. Embedding the planner into Cody's app instead of building a standalone UI is the correct call. I'm on board with the architecture. Below are my answers to your questions, clarifications on what already exists, and a few adjustments to the ownership breakdown.

---

## ANSWERS TO YOUR QUESTIONS

### Does Cody's app already write to SharePoint?

**Yes.** The sales app (`bpt-sales-app`) already has a working SharePoint write pipeline:

- **`/api/pdf-to-sharepoint`** - uploads PDF quotes to SharePoint via Microsoft Graph. It writes to a `{YEAR} Proposals` folder, handles auto-versioning (v2, v3...), and returns the file's web URL.
- **`/api/onedrive-proxy`** - search and read files from SharePoint/OneDrive via Graph Search API.

The infrastructure for "Send to CAD" is already built. The app has Graph API credentials (`SP_GRAPH_CLIENT_ID`, `SP_GRAPH_CLIENT_SECRET`, `SP_SITE_ID`) and a proven pattern for uploading files to SharePoint. Writing a JSON instruction file to a specific folder is a minor extension of what's already working.

**"Send to CAD" implementation:** A new Azure Function (or an extension of the existing `pdf-to-sharepoint`) that accepts the layout JSON, writes it as `{JobID}-instruction.md` to the target folder in the Jobs library. Same auth, same Graph API pattern. Minimal new code.

### Does Cody's app use the same Dataverse org?

**Yes, same org.** `bpt-sales-app` connects to `orge8a4a447.crm.dynamics.com` using the same `BPT Web Apps` app registration (`3973a0f4-e17b-4dfd-aa86-61c569db82a9`). It has its own `dataverse-proxy` function and `dataverse-auth.js` module.

**Jobs are `cr55d_job` records** (same table you're referencing as `cr55d_jobs`). Key fields already in use:

| Field | What It Stores |
|---|---|
| `cr55d_jobid` | Primary key (GUID) |
| `cr55d_jobname` | Event name |
| `cr55d_eventdate` | Event date |
| `cr55d_eventtype` | Event type (wedding, corporate, festival, etc.) |
| `cr55d_quotedamount` | Quote amount |
| `cr55d_salesfolderuri` | Graph item ID for the job's Sales folder in SharePoint |
| `cr55d_productionfolderuri` | Graph item ID for the job's Production folder |

**UID linkage is already there.** When the sales rep is working in a Deal in Cody's app, the app has the `cr55d_jobid` and all associated job data. No manual UID entry needed. The "Send to CAD" function can pull the job ID directly from the Deal context and name the file accordingly.

**HubSpot sync is one-way TO Dataverse** via `hubspot-sync.js`. HubSpot is a CRM mirror, not the source of truth. Dataverse is authoritative.

### Claude API routing: same proxy or separate?

**Separate but similar.** Cody's app has its own `claude-proxy` function at `/api/claude-proxy` (644 lines). It's more mature than the ops app version:

- Uses `@anthropic-ai/sdk` (v0.39.0) with direct Anthropic API key auth
- Currently hardcoded to `claude-opus-4-6`
- 5-minute cache for prompts and product catalog
- Supports both streaming (SSE) and standard JSON responses
- Pulls system prompts from `cr55d_aiinstructions` in Dataverse (with hardcoded fallbacks)
- Retry logic for transient errors (429, 500, 529)
- Token telemetry tracking

**The sales app also has a full tool-use agent** in `/api/job-notes` that uses Claude with 6 tools (search_jobs, submit_notes, retrieve_notes, update_note, delete_note, search_onedrive, read_file, list_fireflies_meetings, get_fireflies_transcript). This is a working example of Claude tool-use in the sales app stack.

**For the tent layout feature:** The modeling knowledge documents would be included as system prompt context in the Claude API call, same way the app already includes product catalog and AI instructions. The `claude-proxy` already supports passing custom system prompts. Jon's modeling knowledge docs would be loaded either from Dataverse (`cr55d_aiinstructions`) or as static context bundled with the prompt.

**Model choice:** The layout generation call should probably use `claude-sonnet-4-6` instead of Opus - it's faster, cheaper, and the spatial layout task is well-structured enough that Sonnet can handle it. The `claude-proxy` currently hardcodes Opus; we'd need to make the model selectable per-call or add a separate endpoint for layout generation. Minor change.

---

## ADJUSTMENTS TO THE OWNERSHIP BREAKDOWN

Jon, your ownership table is mostly right but needs a few corrections based on what actually exists:

### What Changes

| Item | You Said | Actual |
|---|---|---|
| SharePoint file write | Kyle builds | **Already built.** `pdf-to-sharepoint` pattern exists. Cody extends it for JSON instruction files. |
| Dataverse connectivity for Deals | Kyle confirms if it exists | **Confirmed. It exists.** Same Dataverse org, same app registration, `cr55d_job` table. |
| Claude API infrastructure | Kyle manages proxy/key | **Cody's app has its own proxy.** Layout calls go through the sales app's `claude-proxy`, not the ops app's. Kyle manages the API key in Azure App Settings. |
| HubSpot drawing ticket | Kyle automates | **Cody's app already has HubSpot integration** (`hubspot-sync.js`). Creating a drawing ticket from the "Send to CAD" action is Cody's scope, not mine. I'll confirm the right HubSpot pipeline/stage. |

### Updated Ownership

| Owner | Responsibilities |
|---|---|
| **Cody (Sales App)** | App shell, Deal data model, Layout tab container, Claude API call (through existing `claude-proxy`), auto-save to Deal record, "Send to CAD" button (extends existing `pdf-to-sharepoint` pattern), HubSpot drawing ticket creation, model selection for layout calls. |
| **Jonathan (CAD)** | Planner as embeddable React component with defined props interface. Modeling knowledge documents for Claude's system prompt context. Claude spatial layout prompt (the instructions that tell Claude how to generate a tent arrangement from event details). VW plugin on the receiving end. JSON format documentation (VW-13). |
| **Kyle (IT/Infrastructure)** | SharePoint folder path for instruction files (I'll confirm the exact path in the Jobs library). Dataverse table builds for capacity/layout data (once defined with Sales input). API key management in Azure App Settings. Review of any new `cr55d_aiinstructions` entries for the layout prompt (changelog required per our standard). Intune enrollment for Jon's workstation. |

### Handoff Interfaces (Refined)

**Cody to Jonathan:** Same as you described. The planner component props interface. Cody's app passes an initial layout (JSON array from Claude) and receives layout changes via callback. Confirm: is the planner a standalone React component with a clean import, or does it have dependencies on the sales app's state management?

**Jonathan to Cody:** JSON format (VW-13, already delivered), packaged planner component, and the **modeling knowledge documents** that Cody's `claude-proxy` needs as system prompt context. These docs need to be loaded into `cr55d_aiinstructions` or bundled as static files in the sales app's API.

**Cody's app to SharePoint:** Already working. "Send to CAD" is a new function that writes `{JobID}-instruction.md` to the job's folder (using `cr55d_salesfolderuri` to find the right folder, same way `pdf-to-sharepoint` works). Kyle confirms the subfolder name.

---

## FILE STORAGE - FINAL DECISION

**No Queue folder.** Here's why:

Your original proposal had a Queue folder where files stage before the CAD operator picks them up. But now that "Send to CAD" is an explicit button press in Cody's app (not an automatic Claude output), the staging step is unnecessary. The flow is:

1. Sales rep builds/refines layout in the app
2. Sales rep presses "Send to CAD"
3. App writes `{JobID}-instruction.md` to the job's folder in the Jobs SharePoint library (same folder where proposals already go)
4. App creates a HubSpot drawing ticket so Jon knows there's work waiting
5. Jon opens VW, runs Load Job, browses to the Jobs library, finds the file by job ID

The HubSpot ticket IS the queue. Jon doesn't need to browse a staging folder to find work - he checks his ticket pipeline. The file lives with the job from the start.

**Target path:** `Jobs/{JobFolder}/CAD/{JobID}-instruction.md`

I'll create a `CAD` subfolder convention inside job folders so instruction files don't mix with proposals and contracts. Jon's VW plugin browses to this subfolder.

**Jon's question from the original review about the VW plugin file browser:** The plugin can either:
- Browse a synced local path (if Jon's workstation has the Jobs library synced via OneDrive/Intune)
- Or receive the SharePoint file URL from the HubSpot ticket and download via Graph API

Option 1 is simpler for v1. I need to verify Jon's Intune enrollment and push the Jobs library sync policy.

---

## HUBSPOT DRAWING TICKET

Jon, you asked for this and it makes sense. Here's what I need from you:

1. **What HubSpot pipeline should the ticket go to?** Is there an existing pipeline for CAD/drawing work, or do we need to create one?
2. **What fields does the ticket need?** At minimum: job name, job ID, link to instruction file, requesting sales rep. What else?
3. **Do you need stages?** (e.g., Requested > In Progress > Review > Complete) Or just a flat queue?

Cody can build the ticket creation into the "Send to CAD" button. His app already talks to HubSpot.

---

## MODEL SELECTION FOR LAYOUT GENERATION

Worth a brief discussion. The sales app currently uses Opus for everything. For the tent layout generation call specifically:

| Factor | Opus | Sonnet |
|---|---|---|
| Cost per call | ~$0.30-0.50 | ~$0.03-0.05 |
| Speed | 15-30s | 3-8s |
| Quality for structured JSON output | Excellent | Excellent |
| Quality for spatial reasoning | Excellent | Good (test needed) |

**My recommendation:** Start with Sonnet for layout generation. The task is well-constrained (known tent types, known sizing rules, JSON output format). If Sonnet's spatial suggestions aren't good enough, upgrade to Opus. But given the sales rep reviews and edits the layout anyway, Sonnet's speed advantage (3-8s vs 15-30s) matters more than marginal quality.

This requires making the model selectable in `claude-proxy` instead of hardcoded. Small change, worth doing regardless.

---

## ITEMS THAT DON'T CHANGE

Everything from our previous exchange still stands:

- **BOM rules face-to-face** - still needed, still on us to schedule
- **Capacity/layout data from Sales** - still needed before Dataverse tables can be designed
- **Phase 0-1 work** - still entirely Jon's domain, no blockers
- **API key on Jon's workstation** - still needed for Phase 3 (VW plugin direct API calls)
- **Dataverse exports for Claude Project prototyping** - still on my list, will generate .md exports of `cr55d_inventories`, `cr55d_catalogskus`, `cr55d_bomrules`, `cr55d_venuepatterns`
- **VW-13 spec** - reviewed, looks good, JSON format confirmed

---

## ACTION ITEMS

### For Jon
1. Answer the HubSpot ticket questions (pipeline, fields, stages)
2. Confirm the planner component can be cleanly embedded (standalone React component with props interface, no external state dependencies)
3. Coordinate with Cody on the component handoff interface
4. Continue Phase 0-1 - no blockers

### For Cody
1. Review this proposal and confirm alignment with sales app architecture
2. Scope the "Send to CAD" function (extend `pdf-to-sharepoint` pattern)
3. Scope the Layout tab container and Claude API call for layout generation
4. Make `claude-proxy` model-selectable (or add a layout-specific endpoint)
5. Coordinate with Jon on planner component embedding

### For Kyle
1. Create `CAD` subfolder convention in Jobs library
2. Verify Jon's workstation Intune enrollment and push Jobs library sync
3. Confirm HubSpot pipeline for drawing tickets
4. Generate Dataverse .md exports for Jon's prototyping
5. Schedule BOM rules sit-down (Jon + Kyle)
6. Schedule capacity/layout data gathering (Jon + Kyle + Sales)
7. Add modeling knowledge prompt entries to `cr55d_aiinstructions` when Jon delivers them (with changelog entries in `cr55d_promptchangelogs`)

### Meetings Needed
1. **Jon + Cody:** Planner embedding approach, component interface definition
2. **Jon + Kyle:** BOM rules review, category mapping (carry-forward from last round)
3. **Kyle + Cody:** Confirm sales app infra alignment (should be quick - everything checks out)
4. **Jon + Kyle + Sales:** Capacity and layout data gathering
5. **All three:** Final scope and timeline once above conversations are done

---

*Kyle Pearson - IT/Infrastructure, Blue Peak Tents*
