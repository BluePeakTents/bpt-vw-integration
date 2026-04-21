// Local key file template for the Maps + Elevation POC (tests/local-ui.html).
//
// SETUP (one-time, per dev machine):
//
//   1. Get the Maps JS API key and Elevation API key from the BPT
//      shared 1Password vault (ask Kyle for the item name and access
//      if you do not see it). These keys are NOT committed to the
//      repo - the repo is public and committing keys would trigger
//      automatic revocation by Google's secret scanner within hours.
//
//   2. Copy this file to tests/keys.local.js (same directory, drop the
//      ".example" from the filename):
//
//        cp tests/keys.local.example.js tests/keys.local.js
//
//   3. Open tests/keys.local.js and replace the placeholder strings
//      below with the real key values.
//
//   4. Open tests/local-ui.html in a browser (double-click the file,
//      or serve via `python -m http.server 8000` and hit
//      http://localhost:8000/tests/local-ui.html).
//
//      The page auto-loads keys.local.js via a <script> tag, reads
//      window.__BPT_KEYS, pre-fills the key fields, and auto-clicks
//      Load. On success the status banner turns green and map clicks
//      place a tent polygon + query elevation at the click point.
//
// SAFETY: tests/keys.local.js is gitignored (.gitignore line 2). It
// cannot be staged by git - you can verify with:
//
//   git check-ignore -v tests/keys.local.js
//
// Never paste real key values into this template file. Only into
// tests/keys.local.js.

window.__BPT_KEYS = {
  mapsJs: "PASTE_MAPS_JS_API_KEY_HERE",
  elevation: "PASTE_ELEVATION_API_KEY_HERE"
};
