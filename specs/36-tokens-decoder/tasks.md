# Tasks

## Slice 1 - Decode Bumped `/tokens` Response

- [X] T036-S1 Capture the bumped devnet-server `GET /tokens` response shape used
  by the same-revision e2e server.
- [X] T036-S1 Add a RED assertion in `test/Test/MPFS/ClientSpec.purs` that
  exercises that response shape and fails on the old top-level-array decoder.
- [X] T036-S1 Adapt `src/MPFS/Client.purs` and/or
  `src/MPFS/Client/Types.purs` so `Client.getTokens` decodes the new response
  and still returns `Array TokenId`.
- [X] T036-S1 Run the focused test command and `./gate.sh`; commit one
  bisect-safe slice with `Tasks: T036-S1`.

## Orchestrator Finalization

- [ ] T036-F1 Verify the pair's commit, rerun `./gate.sh`, update this task
  list in the accepted slice commit if needed, and report READY-FOR-REVIEW to
  the epic orchestrator.
