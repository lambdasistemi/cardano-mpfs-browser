# WIP

- T60-S1: renamed runtime browser global to `window.MPFS_BASE_URL` so the cage-config verifier's `__MPFS_*__` placeholder scan remains reserved for cage substitutions.
- T60-S2: RED intentionally skipped because this slice is CI YAML and has no unit harness; local proof is YAML parsing plus the unchanged project gate, while live preview publication is checked post-push.
- T60-S2: `.github/workflows/preview.yml` parses locally with `yq '.' .github/workflows/preview.yml`.
- T60-S2: `nix develop -c ./gate.sh` passed locally, including bundle, cage config verification, and 121/121 tests.
- T60-S2: preview CI build step now runs `npm ci && just bundle` inside `nix develop` so fresh checkouts install `@bjorn3/browser_wasi_shim` before esbuild.
