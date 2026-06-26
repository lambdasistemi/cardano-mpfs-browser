# Issue #32: Port `mpfs-spa` Into the Halogen Browser

## User Story

As an MPFS user, I can use `cardano-mpfs-browser` as the canonical MPFS web
client: connect a CIP-30 wallet, browse tokens and facts, verify proof-bearing
read data through the WASM reactor, and build/sign/submit MPFS write
transactions at parity with the mature `mpfs-spa` client.

## Context

`cardano-mpfs-browser` has the target architecture: PureScript, Halogen, a small
npm runtime surface, and the WASM-Haskell verify foundation from #31. Its app UI
is currently a placeholder.

`cardano-mpfs-offchain/mpfs-spa` has the mature feature set: Connect, Facts,
Tokens, and End screens; CIP-30 wallet integration; read paths; write envelope
construction through the cage reactor; wallet signing; transaction assembly; and
submit. That app uses react-basic and MUI, so its UI is reference behavior only.
The port must rebuild the interface in Halogen and keep protocol/crypto work in
the Haskell WASM reactors.

## Functional Requirements

- FR-001: The browser exposes Connect, Tokens, Facts, and End tabs in Halogen.
- FR-002: Tokens are read with the existing `MPFS.Client` API, including the
  bumped `/tokens` decoder from #36.
- FR-003: Facts and pending requests for a selected token are readable from the
  MPFS server and displayed with explicit loading, empty, error, and success
  states.
- FR-004: Proof-bearing read paths that need validation route verification
  through the existing WASM verify reactor rather than through PureScript or JS
  protocol logic.
- FR-005: CIP-30 wallets can be discovered, enabled, refreshed, and used for
  addresses, network, balance, signing, and submit.
- FR-006: Write flows are built through the cage reactor for
  `registerToken`, `insertFact`, `updateFact`, `deleteFact`, `retractRequest`,
  `rejectExpired`, `endCage`, and `updateToken`.
- FR-007: The write flow signs the unsigned transaction with the connected
  wallet, assembles the witness set through the reactor, submits the signed
  transaction, and displays the resulting status or failure.
- FR-008: The shipped browser contains no react-basic UI, MUI, Emotion, or
  `@noble/hashes` additions.

## Non-Goals

- Do not retire `mpfs-spa`; that is tracked by cardano-mpfs-offchain #372.
- Do not implement the csmt-utxo second oracle; that belongs to #33.
- Do not touch the offchain repository.
- Do not replace Haskell/WASM protocol behavior with PureScript or JavaScript
  protocol reimplementations.

## Acceptance Criteria

- Connect/Tokens/Facts/End tabs are present in the Halogen app shell.
- Tokens and facts can be browsed against the same-revision devnet server used
  by `./gate.sh`.
- Wallet connect, address/network/balance display, signing, and submit are wired
  through CIP-30.
- Every MPFS write operation named in FR-006 uses the cage reactor boundary.
- `./gate.sh` passes, including lint, CI, and e2e.
- The final branch contains one bootstrap commit plus one bisect-safe commit per
  implementation slice, each linked to `tasks.md` with a `Tasks:` trailer.
