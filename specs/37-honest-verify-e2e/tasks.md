# Tasks

## Slice 1 - Honest Verify E2E

- [ ] T037-S1 Add a guarded e2e spec in
  `test/Test/MPFS/VerifyE2ESpec.purs` and register it from
  `test/Test/Main.purs` only when `MPFS_BASE_URL` is present.
- [ ] T037-S1 Fetch live same-rev boot facts plus trusted root from
  `mpfs-devnet-server`, assemble the reactor envelope, and assert
  `MPFS.Reactor.verifyEnvelope` returns `Right unit`.
- [ ] T037-S1 Tamper data from the live envelope and assert the same reactor
  returns `Left _`.
- [ ] T037-S1 Add a minimal `MPFS.Client` read helper only if existing client
  methods cannot expose the needed live envelope data.
- [ ] T037-S1 Run the focused e2e command and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [ ] T037-F1 Verify the slice commit and task amendments, update draft PR
  metadata with `Closes #37` and parent `#34`, run the final gate, and report
  `READY-FOR-REVIEW <sha>` to the epic.
