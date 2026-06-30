# Tasks

## Slice 0 - Planning And Gate

- [X] T050-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T050-S0 Open a draft PR linked to `Closes #50` and parent `#47`.

## Slice 1 - Forward Tokens Response To WASM Verifier

- [X] T050-S1 Add or refresh a captured real `/tokens` fixture with non-empty
  entries and non-empty `completeness_proof`.
- [X] T050-S1 Add real reactor tests proving the honest fixture returns
  `verify_ok` after independent UTxO-CSMT root anchoring.
- [X] T050-S1 Add real reactor tests proving a tampered token response returns
  `verify_error`.
- [X] T050-S1 Prove a mismatched independent UTxO-CSMT root fails as not
  anchored before trusted verification succeeds.
- [X] T050-S1 Preserve the raw token response JSON in the client token-load
  path while keeping decoded token ids available to the app.
- [X] T050-S1 Build the `verify_tokens` envelope from the independently
  anchored UTxO-CSMT root, raw response object, and cage config.
- [X] T050-S1 Automatically run `verifyEnvelope` after token load and map
  success to `complete`, failure to `incomplete`.
- [X] T050-S1 Show the Tokens tab `Token list: complete` / `incomplete`
  indicator.
- [X] T050-S1 Run focused tests and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [X] T050-F1 Verify the pair commit, rerun `./gate.sh`, update PR metadata
  with `Closes #50` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
