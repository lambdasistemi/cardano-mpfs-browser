# Tasks

## Slice 0 - Planning And Gate

- [X] T049-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T049-S0 Open a draft PR linked to `Closes #49` and parent `#47`.

## Slice 1 - Repin Offchain Verify Reactor

- [X] T049-S1 Run `nix flake lock --update-input cardano-mpfs-offchain`.
- [X] T049-S1 Confirm the offchain locked revision is `82dc3b9`.
- [X] T049-S1 Confirm the lock diff is limited to `cardano-mpfs-offchain` and
  its follows.
- [X] T049-S1 Build `.#wasm-mpfs-verify` and run the ticket gate if feasible.
- [X] T049-S1 Commit the repin slice with the required `Tasks:` trailer.

## Slice 2 - Forward Lookup Response To WASM Verifier

- [X] T049-S2 Add a captured real `/tokens/:id/facts/:key` fixture with a
  non-empty `fact.mpf_proof`.
- [X] T049-S2 Add real reactor tests proving the honest fixture returns
  `verify_ok` after independent UTxO-CSMT root anchoring.
- [X] T049-S2 Add real reactor tests proving a tampered proof returns
  `verify_error`.
- [X] T049-S2 Prove a mismatched independent UTxO-CSMT root fails as not
  anchored before trusted verification succeeds.
- [X] T049-S2 Preserve the raw fact response JSON in the client lookup path
  while keeping the value available to the app.
- [X] T049-S2 Build the `verify_fact_inclusion` envelope from the independently
  anchored UTxO-CSMT root, raw response object, and lookup key.
- [X] T049-S2 Automatically run `verifyEnvelope` after lookup and map success
  to `Verified`, failure to rejected.
- [X] T049-S2 Remove the manual proof-envelope requirement from the looked-up
  fact UI path.
- [X] T049-S2 Run focused tests and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [X] T049-F1 Verify the pair commits, rerun `./gate.sh`, update PR metadata
  with `Closes #49` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
