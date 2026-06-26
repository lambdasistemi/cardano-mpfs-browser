# Plan

## Scope

Port the mature `mpfs-spa` feature set into the existing Halogen browser in six
ordered, bisect-safe implementation slices. The orchestrator owns this plan and
the PR metadata. Driver/navigator pairs own production and test code in each
slice.

## Source Map

- Existing browser foundation:
  - `src/App.purs`, `src/Main.purs`, `src/bootstrap.js`
  - `src/MPFS/Client.purs`, `src/MPFS/Client/Types.purs`
  - `src/MPFS/Reactor.purs`, `src/MPFS/Reactor.js`
  - existing PureScript specs under `test/Test/MPFS/`
- Mature source reference, read-only:
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/CageHelpers*`
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/Wallet/Cip30*`
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/Http.purs`
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/Submit.purs`
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/Tab/*`
  - `/code/cardano-mpfs-offchain/mpfs-spa/src/MpfsSpa/App.purs`

## Architectural Decisions

- UI is rebuilt in Halogen. React/MUI modules are reference behavior only.
- Protocol logic stays in the WASM reactors. PureScript builds JSON envelopes,
  calls reactor FFI, parses stable one-line reactor verdicts, and renders
  results.
- The existing browser `MPFS.Client` remains the HTTP boundary. Slice 1 may
  extend its wire types and endpoints where the port requires the mature SPA's
  server calls.
- The existing `MPFS.Reactor` verify wiring remains the verify path. The cage
  transaction-building reactor is added as a separate boundary where useful,
  while avoiding duplicated WASI runner code when the existing bridge can be
  generalized safely inside the slice.
- Runtime npm budget remains the Halogen budget: only `@bjorn3/browser_wasi_shim`
  unless an explicitly reviewed slice widens it. PureScript package declarations
  may be added when a slice's typed modules require them, but registry bumps,
  npm additions, lockfile churn unrelated to the declared PureScript deps, and
  flake input revisions require a Q-file to the epic.

## Slice 1 - Logic Libraries and Cage Reactor Boundary

Port the framework-agnostic domain layer needed by later UI slices:

- shared domain types for wallet address, token id, key, value, request id,
  unsigned transaction, trusted root, cage config, and cage error
- cage helper record and WASM-backed implementation
- cage reactor parsers for decode/cage transaction/sign assembly outputs
- CIP-30 wallet FFI module
- HTTP client extensions needed by the mature port, reconciled into
  `MPFS.Client` instead of duplicating a second client
- focused tests for write envelope construction and reactor output parsing

This slice intentionally does not replace the placeholder UI.

## Slice 2 - Halogen App Shell and Tab Routing

Replace the placeholder `App.purs` with a real Halogen application shell:

- top-level state for selected tab, selected token, base URL/client, remote data,
  and connected wallet placeholder state
- Connect, Tokens, Facts, and End tab navigation
- empty but real tab panels with accessible controls and deterministic labels
- CSS/static shell changes needed for a usable app surface
- smoke or component-level proof that the app renders and tab navigation changes
  panels

No read/write behavior beyond the tab shell lands in this slice.

## Slice 3 - Tokens Tab Read Path

Implement the Tokens tab:

- load and refresh token ids through `MPFS.Client.getTokens`
- select a token and publish the selection to app state
- show loading, empty, error, and success states
- preserve #36 decoder behavior and add/extend focused tests where practical
- provide a disabled or placeholder registration control only when it is not yet
  wired to the write flow

## Slice 4 - Facts Tab Read and Verification Path

Implement the Facts tab read workflow:

- load facts, token state, pending requests, and fact lookup for the selected
  token through the client
- render request phase/status data ported from the mature SPA behavior
- route proof-bearing verification through the WASM verify reactor and surface
  verified/error state in the UI
- cover decoding/phase/verification helpers with focused tests

Write buttons remain inert or unavailable until Slice 6.

## Slice 5 - Connect Tab and Wallet State

Implement the Connect tab:

- discover available CIP-30 wallets
- enable a wallet, read network/address/balance/change address, and refresh on
  wallet events where the wallet API supports it
- reject unsupported network state with clear UI feedback
- expose connected wallet state to later write flows
- test pure helpers such as owner key hash extraction and network labelling;
  use FFI fakes where practical for wallet flow smoke

## Slice 6 - Write Flow and End Tab

Complete parity write behavior:

- wire register token, insert/update/delete facts, retract request,
  reject expired, update token, and end cage actions
- build unsigned transactions through the cage reactor helper layer
- sign with CIP-30, assemble witness sets through the reactor, submit via the
  MPFS server, and display operation status
- refresh relevant token/fact/request views after submit
- implement End tab owner/destructive-action UX
- add focused tests for submit state transitions and a gate-level e2e smoke

## Verification

Each slice uses a focused RED/GREEN command chosen by the driver from the
available PureScript test surface, followed by `./gate.sh`. The orchestrator
reruns `./gate.sh` before accepting each slice.

## Forbidden Scope For All Slices

- No edits in `/code/cardano-mpfs-offchain`.
- No react-basic, MUI, Emotion, or `@noble/hashes` additions.
- No npm dependency additions, flake input revisions, or PureScript registry
  bumps unless a slice writes a Q-file and the epic explicitly approves the
  scope expansion.
- No replacing Haskell/WASM verification or transaction-building with JS
  protocol logic.
