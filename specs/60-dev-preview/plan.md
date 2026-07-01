# Plan — #60 Deployable dev.plutimus preview

## Outcome
A PR preview at `preview.dev.plutimus.com/lambdasistemi/cardano-mpfs-browser/pr-<N>/`
runs the real SPA against live `umpfs.plutimus.com` (CORS-enabled in offchain#384)
with no local proxy. SecondOracle already absolute + CORS `*`, untouched.

## Design

### Runtime API base (replaces hardcoded `/api`)
- The base is provided at startup, not compiled in. Default stays `/api` so the
  local same-origin proxy dev flow is unchanged.
- Pure, testable core: `resolveBaseUrl :: Maybe String -> String`
  (`Nothing -> "/api"`, `Just s -> s`).
- Thin FFI: `readApiBaseUrl :: Effect (Maybe String)` reads
  `window.MPFS_BASE_URL` (empty/undefined -> `Nothing`). NOTE: the global is
  deliberately NOT `__MPFS_..__`-wrapped — the cage-config bundle verifier scans
  `/__MPFS_[A-Z0-9_]+__/g` and would flag a wrapped token as an un-substituted
  placeholder.
- Wiring: `Main.purs` reads the base once and passes it as the component Input;
  `App.component` Input becomes `{ baseUrl :: String }`;
  `initialState input = defaultState { baseUrl = input.baseUrl }`.
- Config file: committed `dist/config.js` sets the default
  `window.MPFS_BASE_URL = "/api";`; `dist/index.html` loads it *before*
  `index.js`. `dist/config.js` is tracked (only `dist/index.js` + `dist/*.wasm`
  are gitignored).

### Preview publish
- `.github/workflows/preview.yml` on `pull_request`:
  build (`just bundle` + `just verify-cage-config`), overwrite `dist/config.js`
  with `window.__MPFS_BASE_URL__ = "https://umpfs.plutimus.com";`, then
  `paolino/dev-assets/static-preview@main` publishes `dist/` to
  `preview.dev.plutimus.com/lambdasistemi/cardano-mpfs-browser/pr-<N>/` and
  comments the URL.

## Slices (bisect-safe)
- **Slice 1 — runtime API base.** App code + config file + unit test. After it,
  local default is still `/api`; the base is now injectable. Owned: new
  `RuntimeConfig` module (+ `.js`), `Main.purs`, `App.purs` (Input type +
  initialState), `dist/index.html`, `dist/config.js`, a `test/Test/**` spec.
- **Slice 2 — preview CI.** `.github/workflows/preview.yml` only. Infra; no unit
  harness for CI YAML (documented exception) — proof is the live preview URL.
