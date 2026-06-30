# Tasks

## Slice 0 - Planning And Gate

- [X] T051-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T051-S0 Open a draft PR linked to `Closes #51` and parent `#47`.

## Slice 1 - Forward Facts Response To WASM Verifier

- [ ] T051-S1 Add or refresh a captured real `/tokens/:id/facts` fixture with a
  non-empty `facts` array.
- [ ] T051-S1 Add real reactor tests proving the honest fixture returns
  `verify_ok` after independent UTxO-CSMT root anchoring.
- [ ] T051-S1 Add real reactor tests proving a tampered facts response returns
  `verify_error`.
- [ ] T051-S1 Prove a mismatched independent UTxO-CSMT root fails as not
  anchored before trusted verification succeeds.
- [ ] T051-S1 Preserve the raw facts response JSON in the client facts-load
  path while keeping decoded facts available to the app.
- [ ] T051-S1 Build the `verify_facts` envelope from the independently anchored
  UTxO-CSMT root and raw facts response object.
- [ ] T051-S1 Automatically run `verifyEnvelope` after facts load and map
  success to `Verified`, failure to rejected.
- [ ] T051-S1 Show the Facts tab `Facts set: Verified` / rejected indicator.
- [ ] T051-S1 Run focused tests and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [ ] T051-F1 Verify the pair commit, rerun `./gate.sh`, update PR metadata with
  `Closes #51` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
