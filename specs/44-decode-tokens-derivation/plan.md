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

## Continuation After A-002

The branch was reopened after live browser testing showed `Load facts` still
failed on the fictional `TokenState` JSON contract. Add one more vertical slice
to align the read flow with the real offchain API.

## Slice 3 - Align real read-flow decoders

Expected approach:

1. Copy real fixtures:
   - `/tmp/mpfs44/ticket/answers/real-umpfs-token-state.json`
   - `/tmp/mpfs44/ticket/answers/real-umpfs-facts.json`
   - live-captured root and requests fixtures from
     `/tmp/mpfs44/ticket/live-captures/`.
2. Add RED tests per endpoint:
   - `decodeTokenBody` or equivalent for `/tokens/:id` derives
     `{ owner, root, max_fee, process_time, retract_time }` from the inline
     datum in `state.utxo.tx_out`.
   - facts fixture decodes real `facts: []` with the real `state` envelope.
   - root fixture decodes the real quoted root string.
   - requests fixture decodes real pending request rows from the live response.
3. Reuse existing `decodeTxOutput`, `hexToBytes`, and
   `Tx.PlutusData.interpretDatum`; do not hand-roll another datum parser.
4. Wire `mkClient.getToken` to the new token-state decoder instead of generic
   JSON decode.
5. Extend the existing CBOR and Plutus datum readers where required by the real
   captured request UTxO data, including indefinite-length byte strings and
   Plutus integer values that exceed 32-bit `Int`.
6. Extend the live smoke so it calls the read flow for a real token: tokens →
   token state → facts → root → requests. It must fail on the previous
   `max_fee` MissingValue path.

Owned files:

- `src/MPFS/Client.purs`
- `src/MPFS/Client/Types.purs`
- `src/MPFS/Tx/Cbor.purs`
- `src/MPFS/Tx/Cbor.js`
- `src/MPFS/Tx/PlutusData.purs`
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/MPFS/LiveTokensSmoke.purs`
- `test/Test/MPFS/TxCborSpec.purs`
- `test/fixtures/real-umpfs-token-state.json`
- `test/fixtures/real-umpfs-facts.json`
- `test/fixtures/real-umpfs-token-root.json`
- `test/fixtures/real-umpfs-requests.json`

Forbidden scope:

- No reactor, SecondOracle internals, wallet write-flow, flake, dependency
  manifest, or lockfile changes.

Focused command:

- `nix develop --quiet --command just test`
- `nix develop --quiet --command just smoke-umpfs-tokens`

Commit:

- Subject: `fix(client): decode real umpfs read responses`
- Trailer: `Tasks: T044-S3`

## Continuation After A-003

The second live browser walk proved Slice 3 fixed the token read flow, but the
second oracle remained unreachable because `App.selectedTokenOutputRef` was a
stub. Add one more vertical slice that carries the authoritative selected token
UTxO ref from the real token-state response into app state and proves the app
can call the real second oracle.

## Slice 4 - Reach the real second oracle

Expected approach:

1. Extend `TokenState` with a current output reference derived from
   `/tokens/:id` `state.utxo.tx_in`.
2. Update `decodeTokenBody` so the real token-state fixture preserves
   `{ tx_id, tx_ix }` alongside the datum-derived state fields.
3. Implement `App.selectedTokenOutputRef` by reading loaded token state and
   converting that current ref to `SecondOracle.OutputRef`.
4. Replace the old "does not fabricate" unit assertion with one that fails
   while the stub remains and proves the loaded token-state ref is returned.
5. Add a real boundary proof that the app-selected output ref reaches the real
   `utxo-csmt.plutimus.com` proof/roots path and produces a concrete
   second-oracle verdict with the WASM verifier.
6. Extend the live smoke so it exercises tokens → token state → facts → root →
   requests → second oracle.

Owned files:

- `src/MPFS/Client.purs`
- `src/MPFS/Client/Types.purs`
- `src/App.purs`
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/MPFS/LiveTokensSmoke.purs`
- `test/Test/SecondOracleAppSpec.purs`
- `test/Test/MPFS/SecondOracleSpec.purs`
- `test/Test/FactsSpec.purs`
- `test/fixtures/real-umpfs-token-state.json`

Forbidden scope:

- No wallet write-flow, reactor internals, offchain server, flake, dependency
  manifest, or lockfile changes.
- Do not replace the real second-oracle proof with a mock for the new
  acceptance test.

Focused command:

- `nix develop --quiet --command just test`
- `nix develop --quiet --command just smoke-umpfs-tokens`

Commit:

- Subject: `fix(app): reach second oracle from selected token`
- Trailer: `Tasks: T044-S4`
