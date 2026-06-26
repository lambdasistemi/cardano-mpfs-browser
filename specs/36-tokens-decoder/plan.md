# Plan

## Scope

One bisect-safe implementation slice fixes the `/tokens` decode path only. The
driver/navigator pair must first observe or otherwise capture the bumped
devnet-server response shape, then use that shape as the RED fixture/assertion.

## Current State

- `MPFS.Client.Client.getTokens` currently uses the generic `get` helper at
  `/tokens`, so it requires a `DecodeJson (Array TokenId)` instance.
- `test/Test/MPFS/ClientSpec.purs` currently expects `GET /tokens` to decode to
  `[]` against the live e2e server.
- The reported failure is `Decode error: TypeMismatch "Array"`, which means the
  bumped server no longer returns a top-level JSON array.

## Implementation Strategy

1. Reproduce or inspect the bumped `/tokens` response with the same server path
   used by `just e2e`:
   - `bp=$(nix build --no-link --print-out-paths .#cage-blueprint)`
   - `gd=$(nix build --no-link --print-out-paths .#devnet-genesis)`
   - `E2E_GENESIS_DIR="$gd" nix develop --quiet --command just e2e "$bp"` for
     the full proof, or an equivalent temporary server launch plus `curl
     /tokens` while diagnosing.
2. Add a focused RED assertion in `test/Test/MPFS/ClientSpec.purs` for the new
   `/tokens` JSON shape. The assertion must fail on the old decoder with the
   observed type mismatch and must not be skipped or weakened.
3. Adapt only `src/MPFS/Client.purs` and/or `src/MPFS/Client/Types.purs` so
   `Client.getTokens` returns `Array TokenId` from the new response shape.
4. Run the focused test command, then `./gate.sh`.

## Owned Files For Slice

- `src/MPFS/Client.purs`
- `src/MPFS/Client/Types.purs`
- `test/Test/MPFS/ClientSpec.purs`

## Forbidden Scope

- No `flake.nix`, `flake.lock`, `spago.yaml`, `package.json`, or lockfile
  changes.
- No app UI, reactor, WASM, transaction, proof, or fixture changes.
- No edits to `specs/36-tokens-decoder/*`; the ticket orchestrator owns these.

## Verification

- Focused RED/GREEN command: the driver may use the narrowest useful `spago
  test`/`just test` invocation available in this repo, but must record the
  actual command and assertion failure/pass in its STATUS.
- Full gate: `./gate.sh`.
