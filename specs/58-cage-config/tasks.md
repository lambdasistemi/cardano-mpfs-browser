# Tasks

## Slice 0 - Planning And Gate

- [X] T058-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T058-S0 Open a draft PR linked to `Closes #58` and parent `#47`.

## Slice 1 - Substitute Bundled Cage Config

- [ ] T058-S1 Add a regression proof that the built bundle does not contain
  `__MPFS_` cage-config placeholders.
- [ ] T058-S1 Derive expected `cageScriptBytes`, `requestScriptBytes`, and
  `cfgScriptHash` from `.#cage-blueprint`.
- [ ] T058-S1 Assert all bundled cage-config fields are valid hex and not
  placeholders.
- [ ] T058-S1 Substitute `state.state.mint.compiledCode` into
  `cageScriptBytes`.
- [ ] T058-S1 Substitute `state.state.mint.hash` into `cfgScriptHash`.
- [ ] T058-S1 Substitute `request.request.spend.compiledCode` into
  `requestScriptBytes`.
- [ ] T058-S1 Run focused commands and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [ ] T058-F1 Verify the pair commit, rerun `./gate.sh`, update PR metadata with
  `Closes #58` and parent `#47`, push the branch, and report
  `READY-FOR-REVIEW <sha>` to the epic via STATUS.md.
