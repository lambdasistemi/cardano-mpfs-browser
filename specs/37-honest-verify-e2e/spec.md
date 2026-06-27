# Issue #37: Honest Verify OK E2E Against Same-Rev Devnet

## P1 User Story

As a determinism check, the browser test suite fetches real boot facts and the
trusted root from the same-revision MPFS devnet server and verifies that envelope
through the Haskell WASM verify reactor, so the positive `verify_ok` path is
proved without rev-fragile static honest fixtures.

## Context

Issue #31 added static proof tests for the verify reactor and proved corrupted
proofs return `verify_error`. Those tests deliberately cannot cover the honest
positive path because accepted proof envelopes are coupled to the offchain
revision that produced them.

This ticket adds an e2e spec that runs only when `MPFS_BASE_URL` is set. The
existing `just e2e <blueprint>` harness boots `mpfs-devnet-server` from the same
flake revision, prepares `mpfs-verify-reactor.wasm`, and runs `spago test` with
`MPFS_BASE_URL` pointed at that live server.

## Functional Requirements

- FR-001: The e2e suite fetches a real boot facts envelope and trusted root from
  the live `mpfs-devnet-server` selected by `MPFS_BASE_URL`.
- FR-002: The honest envelope is verified through
  `MPFS.Reactor.verifyEnvelope`, backed by `mpfs-verify-reactor.wasm`, and
  asserts `Right unit`.
- FR-003: The e2e suite tampers a fact or proof value from the same real
  envelope and verifies the tampered envelope through the same reactor,
  asserting `Left _`.
- FR-004: The default unit run remains usable when `MPFS_BASE_URL` is unset; the
  honest e2e spec is registered only under the e2e guard.
- FR-005: No JavaScript or PureScript cryptographic verifier is introduced, and
  no static honest proof fixture is committed.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- `just e2e <cage-blueprint>` runs the new spec against a live devnet server and
  observes an honest `verify_ok`.
- The same e2e run observes `verify_error` after tampering with the live facts
  envelope.
- The final PR links `Closes #37` and parent `#34`.

## Non-Goals

- Do not add static honest proof fixtures.
- Do not change `MPFS.Reactor` or the verify WASM boundary except to consume the
  existing `verifyEnvelope` API.
- Do not edit `src/MPFS/Cage*`, rewrite transaction flows, or add npm
  dependencies.
