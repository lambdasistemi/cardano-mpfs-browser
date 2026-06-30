# Plan

## Technical Shape

This is a narrow hardening pass over the existing PureScript second-oracle
surface. The browser already wires `App.secondOracleDeps.verifyInclusion` to
`MPFS.SecondOracle.CsmtVerify.verifyInclusion`; the missing proof is that the
full verdict tests exercise that real dependency and that all non-matching proof
cases collapse to the mismatch class rather than a separate soft pass/failure.

Existing modules:

- `src/MPFS/SecondOracle.purs`: full verdict flow from output ref, proof/root,
  verifier result, and datum-root extraction.
- `src/MPFS/SecondOracle/Types.purs`: verdict type.
- `src/MPFS/SecondOracle/CsmtVerify.*`: real WASM inclusion verifier boundary.
- `src/MPFS/App/View.purs`: second-oracle UI label.
- `test/Test/MPFS/SecondOracleSpec.purs`: full verdict tests.
- `test/Test/MPFS/SecondOracleCsmtVerifySpec.purs`: primitive verifier tests.
- `test/Test/SecondOracleAppSpec.purs`: UI label tests.

## Slice 1 - Real verifier verdict hardening

One behavior-changing bisect-safe commit handles domain, tests, and UI together
so the project builds after the slice.

Expected approach:

1. RED: add full-path tests in `Test.MPFS.SecondOracleSpec` that construct
   `SecondOracleDeps` with real `CsmtVerify.verifyInclusion` and the real MPFS
   token fixture. The original fixture must verify; a tampered proof, wrong
   merkle root, and wrong expected facts root must return mismatch.
2. GREEN: adjust `SecondOracleVerdict` and `verdictWithRoot` so verifier false
   is represented as the mismatch verdict class, preserving chainpoint and
   root details where available. Keep unavailable only for client/proof/root fetch
   failures and malformed datum only for successful verifier results whose
   datum cannot be decoded as MPFS state.
3. Update `MPFS.App.View.secondOracleStatusLabel` and its tests so the
   user-facing classes are verified, mismatch, unavailable/failure.
4. Keep `App.secondOracleDeps.verifyInclusion = CsmtVerify.verifyInclusion`.
5. Run the focused real-path tests, then `./gate.sh`.

Owned files:

- `src/MPFS/SecondOracle.purs`
- `src/MPFS/SecondOracle/Types.purs`
- `src/MPFS/App/View.purs`
- `test/Test/MPFS/SecondOracleSpec.purs`
- `test/Test/MPFS/SecondOracleCsmtVerifySpec.purs`
- `test/Test/SecondOracleAppSpec.purs`

Forbidden scope:

- `src/MPFS/Reactor.*`
- `src/MPFS/Cage*`
- `src/MPFS/SecondOracle/CsmtVerify.*` unless a compile-only type adjustment is
  strictly necessary.
- `flake.nix`, `flake.lock`, `spago.yaml`, `package*.json`
- fixture replacement or new live-only fixture generation.

Focused command:

```sh
nix develop --quiet --command just test
```

Full gate:

```sh
./gate.sh
```

Commit:

```text
fix(second-oracle): treat real verifier mismatches as mismatch

Tasks: T048-S1
```

## Finalization

The ticket-orchestrator verifies the slice commit and reruns `./gate.sh`, amends
`tasks.md` checkboxes into the accepted slice commit, pushes, updates the draft
PR body with `Closes #48` and parent `#47`, and reports
`READY-FOR-REVIEW <sha>` via `/tmp/mpfs48/ticket/STATUS.md`.
