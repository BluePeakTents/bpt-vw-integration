# TECHNICAL REQUIREMENTS
## Vectorworks + Claude API Integration
### Infrastructure Requirements for IT

**KP Review: 2026-04-02**

| Field | Value |
|---|---|
| Prepared By | Jonathan (Vectorworks / CAD Operations) |
| Audience | Blue Peak IT Department |
| Date | April 2026 |
| Classification | Internal |
| Status | Requirements Gathering |

This document describes what the CAD team is building and what IT infrastructure is needed to support it. The CAD team handles all Vectorworks development and the sales-facing Claude Project. IT provides API access, Dataverse connectivity, UID system access, and shared storage.

This document is also intended to be ingested by Claude as a reference. When IT uses Claude to assist with their portion of the integration, this document ensures Claude has the context needed to give guidance that does not conflict with the Vectorworks architecture.

> **[KP]:** Good call making this Claude-ingestible. I do the same with all our system docs.

---

## 1. WHAT WE ARE BUILDING

Blue Peak is building an end-to-end pipeline from sales request to CAD drawing, with intelligent furniture layout generation. The system has three stages:

**Stage 1 - Sales Intake.** A dedicated Claude Project where sales team members describe event requirements in natural language. Claude interprets the request using two knowledge domains: business knowledge (from Dataverse) defines what the client needs, and modeling knowledge (from custom CAD instruction documents) translates that into the exact model-space components. For example, when sales says "6m x 18m Arcum on 3.5m legs with glass on the south side," the modeling knowledge tells Claude this means: Arcum roof beams, Arcum roof fabric, 3500mm upright legs, fabric walls on North/East/West faces, glass walls on South face. Claude produces a structured instruction file (.md) tagged with the project UID from Blue Peak's IT-managed ID system.

> **[KP - Sales Intake: Key Questions]:**
>
> I want to pressure-test whether a Claude.ai Project is the right delivery mechanism for sales intake vs. a custom UI. Help me understand by answering these:
>
> 1. **What inputs does the sales rep actually have at the point they'd use this?** Is it freeform ("client wants a big tent for 200 people") or structured ("6m x 18m Structure, 3m bays, glass south, fabric other 3 sides")? If it's mostly structured, a form-based UI with Claude doing the translation behind the scenes might be faster than a chat conversation.
>
> 2. **How much back-and-forth do you envision?** If Claude needs to ask 5-8 clarifying questions every time, a guided form that asks those questions upfront eliminates the round trips.
>
> 3. **Does the sales rep need to understand the output?** Section 1 of the .md file is human-readable, but does the sales rep actually review it, or do they just hand it off? If they don't review it, the "chat" UX adds no value over a submit button.
>
> 4. **What about revisions?** When the client changes their mind ("actually make it 24m not 18m"), does the sales rep open a new Claude conversation? Edit the .md by hand? Go through the form again? This workflow matters.
>
> 5. **Do you want sales to see venue history?** We have `cr55d_venuepatterns` with 88 venues and their historical tent configurations. A custom UI could auto-suggest "this venue typically gets a 6m x 18m Structure with glass" before the rep even types anything.
>
> 6. **Would it help if the system pre-filled from the job record?** If the rep already created a job in our system with client name, venue, event date, and guest count, a custom UI could pull all of that automatically. The Claude Project approach requires the rep to re-type it.
>
> **I'm not blocking you from prototyping with a Claude Project.** But if the answers to these questions point toward structured input + auto-populated fields, the production version should be a purpose-built UI in one of our apps with Claude API behind it. The Claude Project becomes your prototyping tool, not the production tool.

**Stage 2 - CAD Execution.** A Vectorworks 2026 plugin command reads the instruction file, presents each tent for operator review, and places parametric tent assemblies in the drawing. The plugin routes each tent to the appropriate existing placement command (Place Structure Tent, Place Arcum Tent, etc.) with the correct parameters. Standard placement is parsed directly from the file with no API call required.

**Stage 3 - Smart Features.** The Vectorworks plugin calls the Claude API directly for advanced capabilities: auto-generating furniture layouts inside placed tent bounds based on event type and guest count, interpreting site plan images for placement coordinates, and mid-workflow adjustments.

The tent generation system is being redesigned with finer component granularity. Individual roof beam styles, multiple wall types (fabric, glass, railing), lattice and grid accessories, gable assemblies, and scaffolding sub-structures will all be independently selectable per bay and per side. Furniture auto-layout will use Blue Peak's existing furniture symbol library and layout standards from Dataverse.

---

## 2. WHAT IT NEEDS TO PROVIDE

### 2.1 Claude API Access

| Requirement | Detail |
|---|---|
| API key | Provisioned under the Blue Peak organization account |
| Deployment | Delivered securely to CAD workstation; stored as Windows environment variable (ANTHROPIC_API_KEY) |
| Model access | Claude Sonnet 4.6 or later |
| Endpoint | POST https://api.anthropic.com/v1/messages |
| Estimated usage | Low volume: 10-50 requests per day during busy season |
| Estimated cost | Under $5/day at typical usage |
| Called from | Vectorworks Python plugin (urllib.request) and claude.ai Projects (sales intake) |

> **[KP - API Key Plan]:**
>
> **Near-term:** I'll deploy our existing `ANTHROPIC_API_KEY` to your workstation as a Windows environment variable. This is the same key our ops app uses. Simple, gets you unblocked.
>
> **Long-term:** I may provision a separate key for the VW workstation so I can track CAD-specific usage independently. Not required for launch.
>
> **Model note:** Claude Sonnet 4.6 is the right choice for the VW plugin calls (fast, cost-effective). For the sales intake side, if we build a custom UI, we could use Sonnet or Opus depending on the complexity of the translation task. We'll test and decide.
>
> **Cost note:** Your $5/day estimate is reasonable for 10-50 Sonnet calls with moderate context. Furniture auto-layout calls (Phase 4) will be larger prompts - could push to $10-15/day during peak. Still very manageable.
>
> **Future consideration:** Our ops app already has a `claude-proxy` Azure Function that handles Claude API calls with logging and error capture. Eventually, routing your VW calls through this proxy (via HTTPS to our SWA) instead of directly to Anthropic would give us centralized usage tracking across all BPT systems. Not v1, but worth designing the VW API call function (Phase 3.3) so the endpoint URL is configurable.

### 2.2 Dataverse Access

Dataverse provides the business knowledge domain: product catalog, inventory, capacity tables, accessory compatibility, furniture catalog, layout standards, and site requirements. Dataverse does not need to contain any Vectorworks modeling data; that is a separate domain maintained by the CAD team.

Preferred: Direct connector or API endpoint that the Claude Project or Claude API tool-use can query at runtime. Read-only access scoped to product and inventory tables.

Fallback: Periodic extraction of relevant tables into structured .md files that the CAD team loads into the Claude Project manually.

> **[KP - Dataverse Access: What Exists Today vs. What You Need]:**
>
> Here's the full picture of what's in Dataverse now and what would need to be built:
>
> **TABLES THAT EXIST:**
>
> | Table | Records | What It Has | What It Doesn't Have |
> |---|---|---|---|
> | `cr55d_inventories` | 992 | Item name, category (Picklist), rentable/broken/total qty, warehouse location, storage position, last count date | No physical dimensions, no compatibility rules, no rental pricing |
> | `cr55d_catalogskus` | varies | SKU, description, category, subcategory, unit, unit price, active flag | Not structured as "tent configurations" - these are line-item SKUs |
> | `cr55d_bomrules` | varies | Tent system, module type/size, component name, quantity, component category, per-unit flag, alternate groups | This is the closest thing to your translation dictionary on the business side |
> | `cr55d_skurules` | 336 | SKU name, core items, common items, rule confidence | Substitution logic, not product specs |
> | `cr55d_venuepatterns` | 88 | Venue name, consistent SKUs, total jobs, ship address | Historical patterns, not prescriptive rules |
> | `cr55d_jobs` | active | Event name, client, venue, date, planner, SP folder URIs | The UID source. Read-only for your purposes. |
>
> **TABLES THAT DON'T EXIST (you're requesting):**
>
> | Your Need | Status | My Questions |
> |---|---|---|
> | Capacity tables (guest count per sqft by event type) | **Needs to be built** | What event types? (seated dinner, cocktail, ceremony, reception, other?) What are the sqft-per-guest numbers? Is this per tent type or universal? Who owns these numbers today - is it tribal knowledge? |
> | Furniture catalog with dimensions | **Needs to be built** | What attributes per piece? (length, width, height, footprint shape, min clearance, weight, stackable?) How many distinct furniture items? Is this a superset of what's in `cr55d_inventories` category 306280009 (Furniture & Fencing)? |
> | Layout standards (spacing, circulation, ADA, fire code) | **Needs to be built** | Is this a rules table or a reference doc? Example: "round tables need 60in center-to-center" - is that a row in a table or a paragraph in a document? How many distinct rules? Are they jurisdiction-specific (Chicago fire code vs. suburban)? |
> | Accessory compatibility | **Partially exists in BOM rules** | What's missing from `cr55d_bomrules`? Is this "which walls fit which tent widths" or something else? |
> | Site requirements (clearances, anchoring, power) | **Needs to be built** | Is this per-venue or per-tent-type? How many distinct rules? Who maintains this? |
>
> **I need you to define these tables in detail before I build them.** For each one, give me:
> - Proposed table name
> - Every column with data type (text, number, picklist, lookup to another table)
> - 3-5 sample rows of real data
> - Who maintains the data and how often it changes
> - Whether it's reference data (rarely changes) or operational data (changes per job)
>
> **Access method - phased approach:**
> 1. **Phase 3 (near-term):** I export the existing tables to .md files on a schedule (weekly or on-demand). You load them into your Claude Project or include them in API call context. Simple, no auth complexity.
> 2. **Phase 3+ (mid-term):** Claude API tool_use (function calling) that queries our `dataverse-proxy` Azure Function in real-time. This gives Claude live data but requires more prompt engineering to define the tools.
> 3. **Phase 4+ (long-term):** If we build the custom sales intake UI, the app queries Dataverse directly (like our ops app already does) and passes structured data to Claude. No tool_use needed because the app does the querying.

Tables Claude needs access to:
- Tent product catalog (styles, available sizes, component options)
- Current inventory (what Blue Peak owns, quantities)
- Capacity tables (guest count per square foot by event type)
- Accessory catalog (wall styles, flooring, liners, lighting, gutters)
- Furniture catalog (tables, chairs, staging, bars, dance floors, lounges)
- Layout standards (spacing rules, circulation, ADA compliance, fire code)
- Site requirement rules (clearances, anchoring, power needs)

### 2.3 UID System Access

Blue Peak's IT architecture includes a UID system that assigns a unique identifier to every project. This UID is referenced across QuickBooks, HubSpot, and other organizational systems. The CAD team will piggyback on this existing UID system to keep instruction files and Vectorworks project files in sync with partner documents across the organization.

Requirement: The sales-facing Claude Project needs the ability to receive or look up the project UID during the intake conversation. At minimum, the sales rep provides the UID manually (they will have it from project creation). If Dataverse integration supports it, Claude could look up the UID automatically. The CAD team does not need to generate UIDs; we consume the existing ones.

> **[KP - UID Clarification]:** This is the job ID from `cr55d_jobs`. It's created when a quote is started and lives with the job through the full lifecycle. The sales rep will always have it because they're working from the job record.
>
> For v1: manual entry by the sales rep is fine.
>
> For a custom UI: the rep would select the job from a dropdown or search, and all job details (client, venue, event date, guest count) auto-populate. This is one of the advantages of the custom UI approach over freeform Claude chat.
>
> **No new system needed here. You're consuming what exists.**

### 2.4 Shared Storage Location

A folder accessible from the CAD workstation where .md instruction files are stored.

| Option | Notes |
|---|---|
| OneDrive (Blue Peak Shared) | Already in use for VW symbol libraries; simplest option |
| SharePoint Document Library | Better access control; can trigger Power Automate notifications |
| Local network path | Fastest; no sync latency; only works on-premises |

The CAD team defines the subfolder structure. IT confirms the root location and ensures read/write access from the CAD workstation.

> **[KP - SharePoint / Shared Storage: GAP Analysis]:**
>
> We just completed a major SharePoint restructure. Here's what exists and how your needs map to it:
>
> **Existing Libraries Relevant to You:**
>
> | Library | Purpose | Your Access (via BPT-Draftsman group) | Relevant? |
> |---|---|---|---|
> | **Jobs** | Job folders (Sales + Production subfolders per job) | Contribute | **Yes** - .md instruction files could live inside the job's folder |
> | **Drawings** | CAD drawings, 7-folder structure | Contribute | **Yes** - your .vwx files likely live here already |
> | **Operations** | Ops docs, procedures | Contribute | Maybe - depends on where VW project docs belong |
> | **Sales** | Sales materials | Contribute | Maybe - if sales-generated .md files need a landing zone |
>
> **Your BPT-Draftsman group already has Contribute access to Jobs, Drawings, Sales, and Operations.**
>
> **Gap Analysis - Where Do .md Instruction Files Go?**
>
> I see three options and I want your input:
>
> **Option A: Inside the job folder (Jobs library)**
> - Path: `Jobs/{JobID} - {ClientName}/{EventName}/instruction.md`
> - Pro: File lives with all other job documents. UID matching is implicit (it's in the job folder).
> - Pro: `cr55d_salesfolderuri` and `cr55d_productionfolderuri` on the job record already point to these folders.
> - Con: Your VW plugin would need to browse into the Jobs library to find the file.
>
> **Option B: Dedicated subfolder in Drawings library**
> - Path: `Drawings/Instructions/{JobID}-instruction.md`
> - Pro: All CAD-related files in one library. Simple flat folder for the VW plugin to browse.
> - Con: Separates the instruction file from the rest of the job's documents.
>
> **Option C: Subfolder in Operations library**
> - Path: `Operations/CAD-Instructions/{JobID}-instruction.md`
> - Pro: Operational workflow docs live in Operations.
> - Con: Similar separation issue as Option B.
>
> **My recommendation: Option A** - put the .md file in the job folder. It keeps everything together, the folder structure already exists, and you already have access. The VW plugin's "Load Job" command could even receive the SharePoint path from the job record's `cr55d_salesfolderuri` field instead of browsing manually.
>
> **Questions:**
> 1. Where are your VW symbol libraries stored in the current SharePoint structure? You mentioned "OneDrive - Blue Peak (Shared) > Library > Symbols" - is this the Drawings library or somewhere else?
> 2. Do you need write access to any library you don't currently have?
> 3. Is your workstation syncing any SharePoint libraries via OneDrive today? If so, which ones?
> 4. For the VW plugin file browser - does it need a local file path (synced via OneDrive) or can it access a SharePoint URL/path directly?
> 5. Do you have any files that need to live outside the current 14-library structure? If so, what and why?
>
> **OneDrive sync status:** We have Intune policies built to auto-sync SharePoint libraries to workstations, but device enrollment is still in progress (your machine may not be enrolled yet). If you're relying on OneDrive sync for the shared folder, I need to verify your device is enrolled and the sync policy is pushing to it.

### 2.5 Network Permissions

- CAD workstation must make outbound HTTPS calls to api.anthropic.com (port 443)
- CAD workstation must have read/write access to the shared storage location
- No inbound ports or firewall rules required; all communication is outbound

> **[KP]:** Straightforward. I'll verify outbound HTTPS from your workstation. Should be fine - no known blocks on 443 outbound.

---

## 3. KNOWLEDGE DOMAIN SEPARATION

The system draws from two independent knowledge domains. Understanding the distinction is critical because IT manages access to one domain (business knowledge via Dataverse) while the CAD team manages the other (modeling knowledge via project documents).

### 3.1 Business Knowledge (Source: Dataverse)

Defines what the client needs. This is the language sales speaks: guest counts, event types, tent dimensions in feet or meters, wall descriptions, venue constraints. Business knowledge sets the boundaries for the job.

Example sales request: "We need a 6m x 18m Arcum tent on 3.5m legs with fabric side walls on 3 sides and glass on the south side, seating for 120 guests at round tables."

Maintained by: Operations, Sales, Product Management (via Dataverse)

### 3.2 Modeling Knowledge (Source: Custom CAD Documents)

Translates what sales asked for into exact model-space components. This is the dictionary that maps every possible sales-language request to its Vectorworks equivalent. The modeling knowledge documents tell Claude which symbols to place, what parameters to set, and how components relate to each other.

Same request translated to model space: Arcum - 6m - Roof Beam (per bay), Arcum - 6m - Roof Fabric (per bay), Arcum - 3500mm - Upright Leg (per gable position), Arcum - 6m - Fabric Wall (North, East, West faces per bay), Arcum - 6m - Glass Wall (South face per bay). Bay count = 18m / bay spacing. Furniture layout: 120 guests at round tables = 15 tables, calculated positions within 6m x 18m interior bounds.

Maintained by: CAD team (Jonathan), via project documents: VW-02, VW-09, VW-10, VW-12, and future additions

### 3.3 How They Work Together

Claude uses business knowledge to understand what the client needs, then uses modeling knowledge to translate that into the exact symbols, parameters, and coordinates that Vectorworks requires. The .md instruction file contains both: Section 1 is the human-readable brief in business language, Section 2 is the machine-readable data in model-space language.

Key principle: Digital models are built to ideal measurements and are not constrained by current physical inventory. Inventory is a business-side concern handled by operations, not the drawing system.

Implication for IT: Dataverse provides business knowledge only. IT does not need to manage, host, or version the modeling documents. If Dataverse schema changes, only the Dataverse connector needs updating. No Vectorworks changes are required.

> **[KP]:** This separation is clean and correct. One addition: if we build a custom sales intake UI, the app itself becomes a third integration point. The app would own the UX, query Dataverse for business knowledge, call Claude API with both business + modeling knowledge in the prompt, and output the .md file. The domain separation still holds - the app is just the orchestrator.

---

## 4. NAMING CONVENTIONS

These conventions are defined by the CAD team and must be respected by any system that references the same product data.

> **[KP]:** Noted. When I build or update Dataverse tables that reference tent products, I'll use your naming convention. One question: the inventory categories in `cr55d_inventories` use names like "Anchor/Shelter", "Atrium", "Navi", "Century Frame", etc. (see the master inventory guide). Your naming convention uses "Structure", "Arcum", "Sailcloth", etc. **Are these 1:1 mappings or different categorization systems?** I need to know so I don't create a disconnect between what's in Dataverse and what your symbols expect.

### 4.1 Universal Symbol Naming Pattern
`[Type] - [Identifiers] - [Component]`

Spaces around all dashes. Title Case. Type always first. Component always last.

### 4.2-4.5 (Tables unchanged - symbol naming, furniture naming, product rules, project file linkage)

*(Content unchanged from original - no KP comments needed on CAD-internal naming conventions)*

---

## 5. SYSTEM ARCHITECTURE OVERVIEW

### 5.1 Technology Stack

| Component | Technology | Notes |
|---|---|---|
| CAD Application | Vectorworks 2026 | Embedded Python (3.11+); plugins via Tools > Plug-in Manager |
| Plugin Language | Python (inside VW) | Standard library only; urllib.request and json confirmed for HTTPS |
| Sales Intake | Claude.ai Project | Shared Project in Blue Peak org account |
| API Communication | Anthropic Messages API | POST api.anthropic.com/v1/messages; x-api-key header |
| Business Data | Microsoft Dataverse | Product catalog, inventory, capacity, layout standards, furniture |
| File Exchange | Shared folder (.md files) | Instruction files from sales Claude Project to VW plugin |
| Symbol Libraries | Vectorworks .vwx files | OneDrive - Blue Peak (Shared) > Library > Symbols |
| Project ID | IT-managed UID system | Single identifier across all organizational systems |

> **[KP - Stack Notes]:**
> - **Sales Intake:** Marked as "Claude.ai Project" - pending our decision on Claude Project vs. custom UI. See Phase 2 questions.
> - **Business Data:** Correct. Our Dataverse org is `orge8a4a447.crm.dynamics.com`. All custom tables use the `cr55d_` prefix.
> - **Symbol Libraries location:** "OneDrive - Blue Peak (Shared) > Library > Symbols" - **Question: Is this synced from a SharePoint library? If so, which one?** This matters for the OneDrive sync policies I'm deploying via Intune.
> - **Project ID:** This is `cr55d_jobs`. No separate "UID system" - the job record IS the UID system.

### 5.2 Data Flow

1. Sales rep receives project UID from the IT-managed ID system
2. Sales rep opens Claude Project, provides UID and describes event in business language
3. Claude uses business knowledge (Dataverse) to understand the request
4. Claude uses modeling knowledge (CAD docs) to translate into model-space components
5. Claude produces .md instruction file tagged with UID
6. Instruction file saved to shared folder
7. CAD operator creates VW project file tagged with same UID
8. Operator runs VW plugin, selects instruction file (matched by UID)
9. Plugin parses file, routes each tent to the appropriate placement command
10. Operator reviews and click-places each tent
11. For furniture: plugin calls Claude API with tent bounds + event details, receives layout
12. Plugin places furniture symbols inside tent bounds

> **[KP - Data Flow with Custom UI (Alternative):]**
> If we go the custom UI route, steps 2-6 change:
> 1. Sales rep creates/selects job in our system (job ID assigned)
> 2. Sales rep opens the intake UI, selects the job (auto-populates client, venue, event date, guest count)
> 3. Sales rep fills in structured fields (tent type, dimensions, wall preferences, accessories)
> 4. App calls Claude API with business knowledge (from Dataverse) + modeling knowledge (from CAD docs loaded as system prompt context) + the structured input
> 5. Claude produces .md instruction file
> 6. App saves the file to the job's SharePoint folder automatically
>
> Steps 7-12 stay the same. The VW side doesn't change at all.

### 5.3 What IT Does NOT Need to Build or Manage

- Vectorworks plugins, scripts, or symbol libraries
- The sales-facing Claude Project system prompt
- The .md instruction file format or parser logic
- Modeling knowledge documents (the translation layer)
- Furniture symbol naming or placement logic
- Any Vectorworks configuration or workspace customization

> **[KP]:** Agreed. Clear boundaries. If we build a custom intake UI, that's an IT deliverable, but it replaces the Claude Project - it doesn't add to your workload.

---

## 6. SECURITY CONSIDERATIONS

| Concern | Mitigation |
|---|---|
| API key exposure | Store as environment variable on authorized workstations only; never in scripts or shared files |
| Client data in prompts | Sales requests contain client names and event details; ensure compliance with Blue Peak data policy |
| Dataverse access scope | Read-only on product/inventory/capacity tables; no customer financial data |
| Network traffic | All outbound HTTPS to api.anthropic.com; no inbound ports required |
| Instruction files | Contain tent specs and client event details; shared folder permissions restrict to authorized personnel |

> **[KP]:** All reasonable. One addition: if we route API calls through our `claude-proxy` in the future, the API key never needs to live on the workstation at all - the proxy handles auth. That's a maturity step, not a launch requirement.

---

## 7. IT ACTION ITEMS

### Immediate (Unblocks Development)

- Provision Claude API key under the Blue Peak organization account
- Deliver API key securely to the CAD workstation
- Confirm outbound HTTPS to api.anthropic.com is permitted from the CAD workstation
- Confirm or create a shared folder location for .md instruction files

> **[KP - Status on Immediate Items]:**
>
> | Item | Status | Next Step |
> |---|---|---|
> | API key | **Have it.** Existing key ready to deploy. | I'll set the environment variable on your workstation. Tell me when you're ready for Phase 3. |
> | Outbound HTTPS | **Need to verify.** | I'll test from your workstation. Should be fine. |
> | Shared folder | **Already exists.** SharePoint libraries are live. BPT-Draftsman group has Contribute on Jobs, Drawings, Sales, Operations. | Answer my questions above about where .md files should live. I think it's the Jobs library inside each job's folder. |

### Near-Term (Enables Full Pipeline)

- Identify which Dataverse tables contain product catalog, inventory, capacity, accessory, furniture, and layout data
- Determine preferred Dataverse access method: direct API connector for Claude, or scheduled export
- If direct API: create read-only service principal scoped to product tables
- If export: establish extraction process and delivery to CAD team
- Confirm how the project UID can be surfaced to the sales-facing Claude Project (manual entry by sales rep, or automated lookup via Dataverse)
- Grant sales team members access to the Blue Peak Claude.ai organization account

> **[KP - Status on Near-Term Items]:**
>
> | Item | Status | Next Step |
> |---|---|---|
> | Identify Dataverse tables | **Done.** See Section 2.2 comments - I've mapped what exists and what doesn't. | You define the new table requirements, I build them. |
> | Access method | **Decided: phased.** Export first (I build the scripts), direct API later. | No action from you. |
> | Service principal | **Already exists.** `dataverse-proxy` function uses client_credentials OAuth. Read-only access to product tables is already possible. | No new principal needed. |
> | UID surfacing | **Decided: manual entry for v1.** Job IDs exist in `cr55d_jobs`. | No action needed. |
> | Claude.ai org access | **Pending decision** on Claude Project vs. custom UI. | Answer my Phase 2 questions first. |

### Future (Enables Automation)

- Evaluate Power Automate for notifications when new .md files arrive in shared folder
- Consider scheduled Dataverse-to-.md extraction if using the export approach
- Evaluate automated UID injection when new projects are created in the ID system

> **[KP]:** All reasonable future items. The Power Automate notification is easy if files land in SharePoint (which they will). Automated UID injection is also straightforward - when a job is created in Dataverse, we can trigger a flow. These are "when we get there" items.

---

## KP Summary - Questions for Jon to Answer

### Priority 1 - Answer Before Phase 2 Work

1. **Sales intake workflow:** Answer the 6 questions in Section 1 about who uses it, when, what inputs they have, revision workflow, etc.
2. **Claude Project vs. custom UI:** After answering #1, what's your reaction to the custom UI alternative? Would you lose anything you need?
3. **Instruction file format:** Confirm JSON for Section 2 (machine-readable portion). Send me the VW-13 spec when ready.

### Priority 2 - Answer Before I Build New Dataverse Tables

4. **New table definitions:** For capacity guide, layout standards, furniture dimensions, and site requirements - give me table name, columns with data types, 3-5 sample rows, change frequency, and who maintains it.
5. **BOM rules overlap:** Review `cr55d_bomrules` and tell me how it relates to your translation dictionary. Same data? Superset? Different purpose?
6. **Category name mapping:** Your symbol naming uses "Structure", "Arcum", "Sailcloth". Our inventory uses "Anchor/Shelter", "Atrium", "Navi", "Century Frame". Are these 1:1? Give me the mapping.

### Priority 3 - Answer Before Phase 3

7. **SharePoint file location:** Where should .md instruction files live? My recommendation is inside the job folder in the Jobs library. Your thoughts?
8. **Symbol library location:** Where exactly are your VW symbol libraries in SharePoint/OneDrive? Is this synced via OneDrive? Which library?
9. **Workstation network:** Can you test hitting an external HTTPS endpoint from VW's Python environment today? (Simple: `urllib.request.urlopen("https://httpbin.org/get")`)
10. **OneDrive sync status:** Is your workstation syncing any SharePoint libraries currently? Which ones?

No IT blockers on your Phase 0-1 work. Start building. I'll work in parallel on API prep, Dataverse exports, and new table design once you send me the requirements.

---

*For questions about the Vectorworks side of this architecture, contact Jonathan. All Vectorworks development, Claude Project configuration, and instruction file format design is handled by the CAD team.*

*For questions about Dataverse, API infrastructure, SharePoint, and the custom UI option, contact Kyle.*
