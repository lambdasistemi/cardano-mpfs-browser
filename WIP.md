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
- T80-S1: RED covered the pure wallet-message dedupe path (`finishWalletDiscovery []` no longer sets duplicate feedback); SVG icon, onboarding hint, and disabled-reason captions are presentational and covered by navigator review plus `./gate.sh`.
- T80-S1 correction: swapped the copy icon from inline Halogen `elementNS` SVG to a CSS `currentColor` mask in `dist/index.html` because the bundled output dropped the inline SVG.
