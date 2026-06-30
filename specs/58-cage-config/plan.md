# Plan

## Technical Shape

Keep `MPFS.App.Config.defaultCageConfig` as the compile-time config surface used
by read verification and write envelopes, but make the browser bundle replace
its three placeholders from the same on-chain blueprint pinned by the flake.
This keeps the config deterministic and avoids adding a runtime `/config`
dependency to the app startup path.

Relevant files:

- `src/MPFS/App/Config.purs`: placeholder-bearing config source whose fields are
  bundled by `spago bundle`.
- `justfile`: `bundle` is the reliable place to substitute and verify the
  browser artifact after `dist/index.js` is produced.
- `scripts/`: a small Node-based helper can parse `plutus.json`, perform the
  replacements, and assert the final bundle shape using only `node`, already in
  the dev shell.
- `test/`: regression coverage should derive values from `.#cage-blueprint`
  rather than hard-coding fake hex.

The script should locate the blueprint JSON regardless of whether the
`cage-blueprint` output is a JSON file directly or a directory containing
`plutus.json`.

## Slice 1 - Substitute Bundled Cage Config

One behavior-changing commit adds the bundle substitution and regression proof.

Expected approach:

1. RED: add a focused regression command or test that builds the bundle from the
   current `.#cage-blueprint` and fails while `dist/index.js` still contains
   `__MPFS_` placeholders.
2. RED: assert the effective bundled `cageScriptBytes`,
   `requestScriptBytes`, and `cfgScriptHash` are valid hex values derived from
   the blueprint, not local fake fixtures.
3. GREEN: add a small build helper that reads the blueprint validators:
   `state.state.mint.compiledCode`, `state.state.mint.hash`, and
   `request.request.spend.compiledCode`.
4. GREEN: call the helper from `just bundle` after concatenating
   `dist/index.js`, so every bundle path substitutes the placeholders and then
   verifies no placeholder remains.
5. GREEN: ensure `just ci` runs the same proof through its existing `bundle`
   step.
6. Run focused commands, then `./gate.sh`.

Owned files:

- `justfile`
- `scripts/substitute-cage-config.mjs` or equivalent helper
- `test/` or script-level regression test files needed for the valid-hex proof

Forbidden scope:

- `src/MPFS/App/Verification.purs`
- `src/App.purs`
- `src/MPFS/App/Tokens.purs`
- `src/MPFS/App/Facts.purs`
- `src/MPFS/Reactor.purs`
- `src/MPFS/Reactor.js`
- `flake.lock`
- `spago.yaml`
- `package*.json`
- Any offchain/onchain repository edits

Focused commands:

```sh
rm -f src/assets/*.wasm
nix develop --quiet --command just bundle
! grep -R "__MPFS_" dist
nix develop --quiet --command just ci
```

Full gate:

```sh
./gate.sh
```

Commit:

```text
fix(config): substitute cage config from blueprint

Tasks: T058-S1
```

## Finalization

The ticket-orchestrator verifies the pair commit, reruns `./gate.sh`, amends the
matching `tasks.md` checkboxes into the accepted slice commit, pushes the
branch, updates the draft PR body with `Closes #58` and parent `#47`, and
reports `READY-FOR-REVIEW <sha>` via `/tmp/mpfs58/ticket/STATUS.md`.
