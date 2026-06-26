# Tasks

## Slice 1 - Logic Libraries and Cage Reactor Boundary

- [X] T032-S1 Add browser-native MPFS domain/cage types and helper records
  needed by the mature port.
- [X] T032-S1 Add cage reactor FFI/parsers for decode, transaction-build, and
  signed-transaction assembly outputs while preserving the existing verify path.
- [X] T032-S1 Add CIP-30 wallet FFI wrappers and pure wallet display helpers.
- [X] T032-S1 Extend the existing `MPFS.Client` read/write HTTP boundary for
  the endpoints needed by the port without duplicating a second client.
- [X] T032-S1 Add focused RED/GREEN tests for write envelope construction,
  reactor output parsing, and pure wallet helpers; run `./gate.sh`.

## Slice 2 - Halogen App Shell and Tab Routing

- [X] T032-S2 Replace the placeholder app with a Halogen shell containing
  Connect, Tokens, Facts, and End navigation.
- [X] T032-S2 Add top-level app state for active tab, selected token, client
  config, remote values, and wallet session state.
- [X] T032-S2 Add empty but real tab panels and static styling for a usable
  browser workbench.
- [X] T032-S2 Add focused render/navigation proof and run `./gate.sh`.

## Slice 3 - Tokens Tab Read Path

- [X] T032-S3 Implement token loading, refresh, empty/error/success states, and
  token selection through `MPFS.Client.getTokens`.
- [X] T032-S3 Preserve the #36 bumped `/tokens` decoder behavior and add or
  extend focused tests where needed.
- [X] T032-S3 Wire selected token state from the Tokens tab into the app shell.
- [X] T032-S3 Run the focused proof and `./gate.sh`.

## Slice 4 - Facts Tab Read and Verification Path

- [X] T032-S4 Implement selected-token facts, token state, pending requests, and
  fact lookup read flows.
- [X] T032-S4 Display request phase/status data and user-readable fact values
  based on the mature SPA behavior.
- [X] T032-S4 Route proof-bearing verification through the WASM verify reactor
  and render verified/error states.
- [X] T032-S4 Cover decoding, phase, and verification helpers with focused tests;
  run `./gate.sh`.

## Slice 5 - Connect Tab and Wallet State

- [ ] T032-S5 Implement CIP-30 wallet discovery, enable, refresh, disconnect,
  and connected wallet display.
- [ ] T032-S5 Read network, used/change addresses, and balance; reject
  unsupported networks with clear UI feedback.
- [ ] T032-S5 Propagate wallet state to the app shell for later write actions.
- [ ] T032-S5 Add focused pure/FFI-fake wallet tests where practical and run
  `./gate.sh`.

## Slice 6 - Write Flow and End Tab

- [ ] T032-S6 Wire register token, insert/update/delete fact, retract request,
  reject expired, update token, and end cage actions through the cage reactor.
- [ ] T032-S6 Sign unsigned transactions with CIP-30, assemble witness sets
  through the reactor, submit signed transactions, and display operation status.
- [ ] T032-S6 Refresh affected token/fact/request views after submit and finish
  the End tab owner/destructive-action workflow.
- [ ] T032-S6 Add focused write-flow tests plus the required e2e proof; run
  `./gate.sh`.

## Orchestrator Finalization

- [ ] T032-F1 Verify every slice commit, rerun `./gate.sh` at HEAD, update PR
  metadata, and report `READY-FOR-REVIEW <sha>` to the epic orchestrator.
