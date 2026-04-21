# bpt-vw-integration - Handoff

Last updated: 2026-04-21

---

## CURRENT STATE

Planning phase plus a validated Google Maps / Elevation POC. Four planning docs in `docs/`:

- VW-11-BuildPlan-KP-Review.md - build plan with KP review comments, awaiting Jon's responses
- VW-13-InstructionFileFormat.md - .md instruction file format spec (Section 1 human, Section 2 JSON)
- IT-Requirements-KP-Review.md - KP review of Jon's IT requirements
- KP-Response-WorkflowProposal.md - KP response to Jon's sales app workflow proposal

**Google Maps / Elevation POC validated 2026-04-21** via `tests/local-ui.html` (opened from `file://`):

- Maps JavaScript API loads at satellite/hybrid map type, zoom 19
- `geometry` library draws tent polygons sized at real-world dimensions (18m x 6m default, configurable length/width/rotation)
- `computeArea` returns the expected m² (confirms correct real-world sizing)
- `google.maps.ElevationService` returns elevation on map click
- Single key currently enabled for both Maps JS and Elevation APIs
- `tests/keys.local.js` (gitignored) holds keys locally; `tests/local-ui.html` auto-populates and auto-loads from it
- `tests/elevation-smoke-test.sh` scaffolded for backend REST-path testing (not yet exercised)

Feature scope (which app, which user, what map does) still undefined. POC proves feasibility only.

---

## KNOWN ISSUES

- Google Cloud API key `AIza...AQUw` was pasted in a Claude Code chat transcript on 2026-04-21. Per user decision the key has not been rotated and is in use for the POC. Assume known to anyone with chat access. Mitigation deferred; see NEXT STEP 1.
- Committing any API key to this repo while it is public would expose the key to GitHub's automated scanners, search engines, archive.org, and bots that harvest public repos for credentials within minutes. GitHub + Google partner on secret scanning and will likely auto-revoke a Google key pushed here, which would also break the POC. If keys must live in the repo at any point, flip the repo to private first.

---

## OPEN DECISIONS

- Sales intake architecture: Claude Project vs custom UI in ops/sales app (KP-preferred). Blocked on Jon answering the 7 questions in VW-11 Phase 2 comments.
- Google Maps feature: which app, which user, what the map does, what the input is (venue name, address, lat/lng). Spec not yet written. API stack decided (see Key Decisions Log).
- API access pattern for v1: direct call from VW to api.anthropic.com vs through `claude-proxy` Azure Function.
- Dataverse near-term delivery: export-to-md script vs direct API via `dataverse-proxy`.
- Dev key distribution to Cody. Options: (a) share out-of-band via Slack/1Password/email, Cody creates his own `tests/keys.local.js` from `tests/keys.local.example.js`; (b) make repo private again, commit keys to repo, revert to public when done; (c) commit to public repo — not recommended, see KNOWN ISSUES.

---

## NEXT STEPS

1. **Rotate and restrict Google Cloud API keys** (exposed key still in use as of 2026-04-21 per user decision; POC validated with exposed key). When rotated, split into two keys so backend and browser can apply different restriction types:
   - **Key A - backend (Elevation REST):** IP-restricted to the Azure Function outbound IP. Stored as `GOOGLE_MAPS_ELEVATION_KEY` in `local.settings.json` and SWA Application Settings. Used by `elevation-proxy` Azure Function and by `tests/elevation-smoke-test.sh`.
   - **Key B - browser (Maps JavaScript API + ElevationService):** HTTP-referrer-restricted to app domains (e.g. `https://<appname>.azurestaticapps.net/*`, `http://localhost:*/*` for dev). Stored as `GOOGLE_MAPS_JS_KEY`. Used by the browser to load Maps JS and call `ElevationService` (same SDK, same key). Referrer-restricted browser keys are designed to be visible.
2. Define the Google Maps feature scope: which app, which user, what the map does, what the input is (venue name, address, lat/lng). Required before spec can be written.
3. Distribute keys to Cody for local dev. See OPEN DECISIONS re: delivery mechanism.
4. Jon to answer the 7 sales intake questions in VW-11 Phase 2 comments so Claude Project vs custom UI decision can close.
5. Jon to define new Dataverse table requirements (capacity guide, layout standards, site requirements, furniture dimensions) per VW-11 Phase 2 action items.

---

## KEY DECISIONS LOG

- **2026-04-21** - Section 2 of .md instruction files will use embedded JSON (not YAML or structured markdown). Rationale: consistency with every other BPT system that speaks JSON (Dataverse API, Azure Functions, QBO queries). Documented in VW-13.
- **2026-04-21** - Google Maps integration, if built, will follow the proxy pattern (`maps-proxy` or equivalent Azure Function), same shape as `dataverse-proxy`, `claude-proxy`, `qbo-query`. Rationale: keeps keys off the frontend, enables centralized logging and caching, allows provider swap without touching callers.
- **2026-04-21** - Google API stack for the map feature: **Maps JavaScript API** for the interactive 2D satellite view (load with `libraries: ['geometry', 'drawing']`), plus **Elevation API** for site grade/slope checks. Rationale: the Embed API is too limited (no custom markers, no click handlers, no polygons at real-world scale). Maps JavaScript API supports polygons/rectangles/circles sized in lat/lng and meters — suitable for rendering tent footprints at actual dimensions. The `geometry` library handles spherical math (compute corner lat/lngs from center + length + width + rotation, distance, area). The `drawing` library gives an interactive UI for users to draw footprints. Elevation API called from a backend proxy; JS API called from the browser with a referrer-restricted key. Pricing: JS API ~$7/1k loads with ~28,500 free loads/month from the $200 credit; Elevation API ~$5/1k requests. Mercator distortion is negligible at tent scale in continental US.
- **2026-04-21** - **Two elevation access paths by layer:** browser code uses `google.maps.ElevationService` (part of the Maps JS SDK), backend code uses the raw REST endpoint `https://maps.googleapis.com/maps/api/elevation/json`. Rationale: the REST endpoint does not return CORS headers for browser origins (empirically confirmed during the POC — `file://` origin `null` was blocked, and even `localhost` would not receive CORS headers). `ElevationService` routes the same query through the Maps JS auth path using the Maps JS key. Implication for the production proxy: the proxy only needs to handle server-side callers (other Azure Functions, the VW plugin); browser callers in ops-app / sales-app UIs should use `ElevationService` directly and avoid a round-trip.

---

## ASSUMPTIONS & UNKNOWNS

- Assumed: VW Python environment on the CAD workstation can make outbound HTTPS calls with modern TLS. Not yet verified. Blocks Phase 3.
- Assumed: sales rep will enter the job UID manually for v1. Confirmed by KP in VW-11 review.
- Unknown: which Google Maps feature is actually being built (see OPEN DECISIONS).
- Unknown: whether venue records in Dataverse (`cr55d_venuepatterns`, or `cr55d_jobs.cr55d_venue`) have addresses or lat/lng, or whether address/geocoding has to be added. If only free-text venue names exist, a Geocoding API step will be needed (separate Google product, must be enabled and keyed separately).
