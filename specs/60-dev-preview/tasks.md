# Tasks — #60

## Slice 1 — runtime API base
- [X] T60-S1 `resolveBaseUrl :: Maybe String -> String` (pure) with a RED unit
      test (`Nothing -> "/api"`, `Just "x" -> "x"`), a `readApiBaseUrl` FFI
      reading `window.MPFS_BASE_URL`, `Main.purs` + `App.component` Input
      wiring (`initialState` sets `baseUrl` from input), committed
      `dist/config.js` (default `/api`) loaded by `dist/index.html` before
      `index.js`. Gate green (`./gate.sh`). One commit.

## Slice 2 — preview CI
- [X] T60-S2 `.github/workflows/preview.yml` (on `pull_request`): build the SPA,
      overwrite `dist/config.js` -> `https://umpfs.plutimus.com`, publish `dist/`
      via `paolino/dev-assets/static-preview@main`, comment the URL. One commit.
