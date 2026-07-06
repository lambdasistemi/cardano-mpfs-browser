# WIP

- T60-S1: renamed runtime browser global to `window.MPFS_BASE_URL` so the cage-config verifier's `__MPFS_*__` placeholder scan remains reserved for cage substitutions.
- T60-S2: RED intentionally skipped because this slice is CI YAML and has no unit harness; local proof is YAML parsing plus the unchanged project gate, while live preview publication is checked post-push.
- T60-S2: `.github/workflows/preview.yml` parses locally with `yq '.' .github/workflows/preview.yml`.
- T60-S2: `nix develop -c ./gate.sh` passed locally, including bundle, cage config verification, and 121/121 tests.
- T60-S2: preview CI build step now runs `npm ci && just bundle` inside `nix develop` so fresh checkouts install `@bjorn3/browser_wasi_shim` before esbuild.
- T64-S1: RED intentionally skipped because this slice is a render retrofit over the already-tested `HashChip`/`truncateMiddle` Material primitives; proof is focused compile plus `./gate.sh`.
- T64-S1: converted `View.purs` sites to `HashChip`: header Token status pill; Connect wallet Address; Tokens Selected token; Facts Token; End Token; End wallet address; token list rows; token state Owner and Root; trusted root hash; pending request id/key/value rows; fact key/value rows; fact lookup value; submitted transaction id.
- T64-S1: constrained overflow contexts in `dist/index.html` for panel/grid/list/field/control/hash-row children so long request/fact bytes live inside bounded `.hash-chip` elements.
- T75-S1: before, fact/request key and value chips rendered UTF-8 JSON as raw hex and some constrained contexts let hash-chip copy buttons wrap; after, those data fields decode to readable copyable text when valid while identifier hashes stay hash chips, and hash-chip copy buttons use a fixed inline flex footprint.
- T77-S1: RED intentionally skipped because this slice is a presentational form-control retrofit with no new pure logic; proof is navigator review plus `./gate.sh` green.
- T67-S1: Facts table ports the design table into the shell; row Proof drawer (#69) and Edit dialog (#70) are intentionally rendered as placeholders only in this slice.
- T80-S1: RED covered the pure wallet-message dedupe path (`finishWalletDiscovery []` no longer sets duplicate feedback); SVG icon, onboarding hint, and disabled-reason captions are presentational and covered by navigator review plus `./gate.sh`.
- T80-S1 correction: swapped the copy icon from inline Halogen `elementNS` SVG to a CSS `currentColor` mask in `dist/index.html` because the bundled output dropped the inline SVG.
2026-07-05T06:45:14+01:00 T65-S1: RED targets app shell workspace tab model and token-select tab reset. Presentational pixel/layout changes will be covered by navigator review and gate.
- T68-S1: Pending Retract buttons call the existing `RetractRequest` action when gated enabled; review/sign UX remains #70. Pending proof chips are placeholders for the #69 proof drawer.
- T69-S1: Verification drawer opens per set, fact, and pending request. The current app state retains facts-set and pending-request verification envelopes, but not separate per-fact/request raw proof payloads; scoped fact/request drawers therefore show the relevant set/snapshot envelope with an in-drawer fallback note.
