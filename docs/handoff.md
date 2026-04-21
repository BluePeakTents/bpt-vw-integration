# bpt-vw-integration - Handoff

Last updated: 2026-04-21

---

## CURRENT STATE

Planning phase. No code yet. Four planning docs in `docs/`:

- VW-11-BuildPlan-KP-Review.md - build plan with KP review comments, awaiting Jon's responses
- VW-13-InstructionFileFormat.md - .md instruction file format spec (Section 1 human, Section 2 JSON)
- IT-Requirements-KP-Review.md - KP review of Jon's IT requirements
- KP-Response-WorkflowProposal.md - KP response to Jon's sales app workflow proposal

Exploring a Google Maps / Elevation API feature (details TBD). Elevation API is the likely candidate for venue site slope/grade checks. No feature spec written yet.

---

## KNOWN ISSUES

- Google Cloud API key `AIza...AQUw` was pasted in a Claude Code chat transcript on 2026-04-21. Assume exposed. Rotate before use. See NEXT STEPS.

---

## OPEN DECISIONS

- Sales intake architecture: Claude Project vs custom UI in ops/sales app (KP-preferred). Blocked on Jon answering the 7 questions in VW-11 Phase 2 comments.
- Google Maps feature: which app, which user, what the map does, what the input is (venue name, address, lat/lng). Spec not yet written. API stack decided (see Key Decisions Log).
- API access pattern for v1: direct call from VW to api.anthropic.com vs through `claude-proxy` Azure Function.
- Dataverse near-term delivery: export-to-md script vs direct API via `dataverse-proxy`.

---

## NEXT STEPS

1. **Rotate and restrict Google Cloud API keys** (one key already exposed 2026-04-21). Two-key split required because backend and browser need different restriction types on the same APIs.
   - **Key A - backend (Elevation API):** IP-restricted to the Azure Function outbound IP. Stored server-side only as `GOOGLE_MAPS_ELEVATION_KEY` in `local.settings.json` and SWA Application Settings. Elevation API is already enabled in the Cloud project.
   - **Key B - browser (Maps JavaScript API):** HTTP-referrer-restricted to app domains (e.g. `https://<appname>.azurestaticapps.net/*`, `http://localhost:*/*` for dev). Enable the `Maps JavaScript API` product in the Cloud project. Stored as `GOOGLE_MAPS_JS_KEY`. Referrer-restricted browser keys are designed to be visible.
   - Delete the exposed key first before creating the two new keys.
2. Define the Google Maps feature scope: which app, which user, what the map does, what the input is (venue name, address, lat/lng). Required before spec can be written.
3. Jon to answer the 7 sales intake questions in VW-11 Phase 2 comments so Claude Project vs custom UI decision can close.
4. Jon to define new Dataverse table requirements (capacity guide, layout standards, site requirements, furniture dimensions) per VW-11 Phase 2 action items.
5. Repo migration: transfer `kpearson-bpt/bpt-vw-integration` to `BluePeakTents` org and set public. Pre-flight sensitivity review done 2026-04-21 (Dataverse org URL and Azure AD client ID present but not credentials; see notes in conversation).

---

## KEY DECISIONS LOG

- **2026-04-21** - Section 2 of .md instruction files will use embedded JSON (not YAML or structured markdown). Rationale: consistency with every other BPT system that speaks JSON (Dataverse API, Azure Functions, QBO queries). Documented in VW-13.
- **2026-04-21** - Google Maps integration, if built, will follow the proxy pattern (`maps-proxy` or equivalent Azure Function), same shape as `dataverse-proxy`, `claude-proxy`, `qbo-query`. Rationale: keeps keys off the frontend, enables centralized logging and caching, allows provider swap without touching callers.
- **2026-04-21** - Google API stack for the map feature: **Maps JavaScript API** for the interactive 2D satellite view (load with `libraries: ['geometry', 'drawing']`), plus **Elevation API** for site grade/slope checks. Rationale: the Embed API is too limited (no custom markers, no click handlers, no polygons at real-world scale). Maps JavaScript API supports polygons/rectangles/circles sized in lat/lng and meters — suitable for rendering tent footprints at actual dimensions. The `geometry` library handles spherical math (compute corner lat/lngs from center + length + width + rotation, distance, area). The `drawing` library gives an interactive UI for users to draw footprints. Elevation API called from a backend proxy; JS API called from the browser with a referrer-restricted key. Pricing: JS API ~$7/1k loads with ~28,500 free loads/month from the $200 credit; Elevation API ~$5/1k requests. Mercator distortion is negligible at tent scale in continental US.

---

## ASSUMPTIONS & UNKNOWNS

- Assumed: VW Python environment on the CAD workstation can make outbound HTTPS calls with modern TLS. Not yet verified. Blocks Phase 3.
- Assumed: sales rep will enter the job UID manually for v1. Confirmed by KP in VW-11 review.
- Unknown: which Google Maps feature is actually being built (see OPEN DECISIONS).
- Unknown: whether venue records in Dataverse (`cr55d_venuepatterns`, or `cr55d_jobs.cr55d_venue`) have addresses or lat/lng, or whether address/geocoding has to be added. If only free-text venue names exist, a Geocoding API step will be needed (separate Google product, must be enabled and keyed separately).
