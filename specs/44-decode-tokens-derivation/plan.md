# Plan

## Scope

Two bisect-safe slices fix the decoder first, then add the live-boundary proof
and backend pointer. The decoder slice is the behavioral fix; the smoke slice is
the guard against repeating the empty-fixture failure.

## Current State

- `decodeTokensBody` decodes the envelope but errors on any non-empty
  `tokens.entries`.
- `TokenUtxoEntry` currently keeps only `txout_cbor`; the live schema also
  carries `ref`, which can be modeled if useful for diagnostics.
- `MPFS.Tx.Cbor.decodeTxOutput` already decodes TxOut CBOR into `TxOutput`,
  including `value.assets`.
- `Test.Main` only includes `ClientSpec` when `MPFS_BASE_URL` is set, so a pure
  fixture assertion inside the current `ClientSpec.spec` would not run under
  `just ci`. The implementation slice may edit `test/Test/Main.purs` narrowly to
  keep pure client decoder tests in CI while preserving live tests behind an
  environment gate.
- The app default base URL is `/api`; served deployments can keep that proxy,
  but new smoke/operator recipes must target `https://umpfs.plutimus.com`.

## Slice 1 - Decode real token entries

Implement RED/GREEN around the captured real fixture.

Expected approach:

1. Copy `/tmp/mpfs44/ticket/answers/real-umpfs-tokens.json` to
   `test/fixtures/real-umpfs-tokens.json`.
2. Add a RED assertion that reads that fixture and expects exactly the two live
   token ids listed in `spec.md`.
3. Ensure the RED assertion runs in `just ci`; if needed, split pure client
   decoder tests from live `MPFS_BASE_URL` tests in `Test.Main`.
4. Implement `decodeTokensBody` by reusing `decodeTxOutput` and `hexToBytes`.
   Do not hand-roll a second TxOut parser.
5. Keep the empty `entries` case returning `[]`.

Owned files:

- `src/MPFS/Client.purs`
- `src/MPFS/Client/Types.purs`
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/Main.purs`
- `test/fixtures/real-umpfs-tokens.json`

Forbidden scope:

- No reactor, SecondOracle, wallet, flake, dependency manifest, or lockfile
  changes.
- No fabricated token fixtures and no empty-only coverage.

Focused command:

- `nix develop --quiet --command spago test`

Commit:

- Subject: `fix(client): derive token ids from txout assets`
- Trailer: `Tasks: T044-S1`

## Slice 2 - Add live boundary smoke

Add an operator-runnable smoke that proves the real boundary: live `umpfs`
response -> `MPFS.Client` decode path -> at least one token id.

Expected approach:

1. Add a narrow smoke test module or script entry point that uses
   `mkClient "https://umpfs.plutimus.com"` and asserts the returned token array
   is non-empty.
2. Add a `just smoke-umpfs-tokens` recipe or script wrapper that runs only that
   live smoke, not the full devnet-only `VerifyE2ESpec`.
3. Update `./gate.sh` expectations only if the command shape changes; the final
   gate must include the live smoke.
4. Document the live backend as `https://umpfs.plutimus.com` where the recipe or
   operator docs mention the backend.

Owned files:

- `justfile`
- `scripts/smoke-umpfs-tokens.sh`
- `test/Test/MPFS/LiveTokensSmoke.purs`
- `README.md` or another minimal operator doc if needed for the backend pointer

Forbidden scope:

- No deployment, flake, dependency manifest, reactor, or SecondOracle internals
  changes.

Focused command:

- `nix develop --quiet --command just smoke-umpfs-tokens`

Commit:

- Subject: `test(client): smoke live umpfs token decoding`
- Trailer: `Tasks: T044-S2`

## Verification

Final ticket gate:

```sh
./gate.sh
```

The gate removes stale local wasm assets first, then runs lint, `just ci`, the
devnet e2e recipe, and the live `umpfs` token smoke.
