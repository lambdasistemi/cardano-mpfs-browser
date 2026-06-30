# Tasks

## Slice 0 - Planning And Gate

- [X] T052-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T052-S0 Open a draft PR linked to `Closes #52` and parent `#47`.

## Slice 1 - Forward Requests Response To WASM Verifier

- [X] T052-S1 Add or refresh a captured real `/tokens/:id/requests` fixture with
  non-empty `request_set.entries`.
- [X] T052-S1 Add real reactor tests proving the honest fixture returns
  `verify_ok` after independent UTxO-CSMT root anchoring.
- [X] T052-S1 Add real reactor tests proving a tampered requests response
  returns `verify_error`.
- [X] T052-S1 Prove a mismatched independent UTxO-CSMT root fails as not
  anchored before trusted verification succeeds.
- [X] T052-S1 Preserve the raw requests response JSON in the client facts-load
  path while keeping decoded pending requests available to the app.
- [X] T052-S1 Build the `verify_snapshot` envelope from the independently
  anchored UTxO-CSMT root, raw requests response object, cage config, and token
  id.
- [X] T052-S1 Automatically run `verifyEnvelope` after pending requests load and
  map success to `Verified`, failure to rejected.
- [X] T052-S1 Show the Facts tab `Pending requests: Verified` / rejected
  indicator.
- [X] T052-S1 Run focused tests and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [X] T052-F1 Verify the pair commit, rerun `./gate.sh`, update PR metadata with
  `Closes #52` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
