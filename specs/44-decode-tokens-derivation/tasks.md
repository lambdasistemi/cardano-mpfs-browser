# Tasks

## Slice 1 - Decode Real Token Entries

- [X] T044-S1 Copy the real two-entry `umpfs` fixture into
  `test/fixtures/real-umpfs-tokens.json`.
- [X] T044-S1 Add a RED fixture assertion that decodes the real response and
  expects token ids
  `976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6` and
  `98207724b0ea59b96c0eba16cb09e91da10f8bdc54ad36da4a2e40104a59a32b`.
- [X] T044-S1 Ensure that assertion runs under `just ci`, not only when
  `MPFS_BASE_URL` is set.
- [X] T044-S1 Implement `decodeTokensBody` by decoding each `txout_cbor` TxOut
  and deriving the token id from the cage asset name.
- [X] T044-S1 Run the focused test command and commit one bisect-safe slice with
  `Tasks: T044-S1`.

## Slice 2 - Live Boundary Smoke

- [X] T044-S2 Add an operator smoke against `https://umpfs.plutimus.com/tokens`
  that decodes through the real `MPFS.Client` path and asserts at least one token
  id.
- [X] T044-S2 Add the corresponding `just` recipe or script entry point.
- [X] T044-S2 Make the backend pointer in operator-facing docs/recipes use
  `umpfs.plutimus.com`, not stale `mpfs.plutimus.com`.
- [X] T044-S2 Run the focused live smoke and commit one bisect-safe slice with
  `Tasks: T044-S2`.

## Orchestrator Finalization

- [X] T044-F1 Verify both pair commits, rerun `./gate.sh`, push the branch, and
  report `READY-FOR-REVIEW <sha>` via `/tmp/mpfs44/ticket/STATUS.md`.

## Slice 3 - Align Real Read-Flow Decoders

- [ ] T044-S3 Copy real token state, facts, root, and requests fixtures into
  `test/fixtures/`.
- [ ] T044-S3 Add RED tests for `/tokens/:id`, `/tokens/:id/facts`,
  `/tokens/:id/root`, and `/tokens/:id/requests` using real non-empty/live
  response shapes.
- [ ] T044-S3 Decode token state from `state.utxo.tx_out` inline datum using the
  existing TxOut and Plutus datum decoders.
- [ ] T044-S3 Align pending request decoding with the real `umpfs` response
  shape.
- [ ] T044-S3 Extend the live smoke to exercise tokens → token state → facts →
  root → requests against `https://umpfs.plutimus.com`.
- [ ] T044-S3 Run the focused test and live smoke commands, then commit one
  bisect-safe slice with `Tasks: T044-S3`.

## Orchestrator Finalization After A-002

- [ ] T044-F2 Verify the read-flow pair commit, rerun `./gate.sh`, push the
  branch, update PR metadata, and report `READY-FOR-REVIEW <sha>`.
