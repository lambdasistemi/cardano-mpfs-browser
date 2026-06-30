# Tasks

## Slice 0 - Planning And Gate

- [X] T048-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T048-S0 Open a draft PR linked to `Closes #48` and parent `#47`.

## Slice 1 - Real Verifier Verdict Hardening

- [X] T048-S1 Add real-data full verdict tests using
  `test/fixtures/csmt-utxo-verdict-real-mpfs-token.json` and real
  `CsmtVerify.verifyInclusion`.
- [X] T048-S1 Prove the original fixture returns verified through
  `checkOutputRef`.
- [X] T048-S1 Prove a tampered proof, wrong merkle root, and mismatched expected
  datum root return mismatch through `checkOutputRef`.
- [X] T048-S1 Normalize verifier false / wrong-root outcomes to the mismatch
  verdict class while keeping unavailable for client/fetch/decode failures.
- [X] T048-S1 Keep the UI label distinct: verified vs mismatch vs unavailable.
- [X] T048-S1 Run the focused real-path tests and `./gate.sh`, then commit the
  slice.

## Orchestrator Finalization

- [ ] T048-F1 Verify the pair commit, rerun `./gate.sh`, update PR metadata with
  `Closes #48` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
