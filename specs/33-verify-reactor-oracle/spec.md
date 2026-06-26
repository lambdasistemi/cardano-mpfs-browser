# Issue #33: Dedicated Verify Reactor and csmt-utxo Second Oracle

## P1 User Story

As an MPFS user, the browser verifies proof-bearing read data through the
dedicated Haskell WASM verify reactor and independently confirms the selected
MPFS token anchor UTxO against the csmt-utxo oracle, so the UI can show both the
MPFS proof verdict and a second-oracle verdict without relying on PureScript or
JavaScript crypto.

## Context

Issue #31 established that pure proof verification belongs in the
`mpfs-verify-reactor.wasm` boundary, using the `verify_ok` and `verify_error`
stdout contract. Issue #32 ported the mature MPFS SPA flows into this Halogen
browser and added write flows that need the cage transaction reactor.

The current branch starts from the merged #32 port. It has a verification module,
but the bridge is still named `runCageReactor`, and the cage reactor module
reuses the same foreign implementation. This ticket first makes the pure verify
boundary explicit and separate from the cage transaction boundary. It then adds
the csmt-utxo second trust oracle from `https://utxo-csmt.plutimus.com`.

## Functional Requirements

- FR-001: Pure proof verification used by the Facts tab routes through a
  verify-only boundary backed by `mpfs-verify-reactor.wasm`, with tests covering
  a known accepted verifier response and a corrupted proof verifier response.
- FR-002: The cage transaction-building boundary remains separate from pure
  verification. Code, names, globals, tests, and asset preparation must not imply
  that tx-building uses the verify reactor.
- FR-003: The browser consumes the neutral `mts:csmt-verify-wasm` artifact from
  the existing `cardano-mpfs-offchain` flake input as a second verifier module.
- FR-004: A csmt-utxo REST client supports `GET /merkle-roots` and
  `GET /proof/:txId/:txIx`, decoding chainpoint-keyed `{slotNo, blockHash,
  merkleRoot}` roots and `{slotNo, blockHash, proof, txOut}` proof responses.
- FR-005: For the selected token's current output reference, the browser fetches
  the csmt-utxo proof and matching root, runs `verifyInclusionProof root proof`
  through the neutral WASM verifier, decodes the attested TxOut datum using the
  existing browser decode boundary, and compares it with the MPFS facts root.
- FR-006: The UI shows a second-oracle state for the selected token:
  not checked, checking, verified, mismatch, or error.
- FR-007: The implementation adds no PureScript trie verifier, no JavaScript
  crypto, no `@noble/*` dependency, and no runtime npm dependency increase
  beyond already approved WASM-shim use unless the epic approves it by Q-file.

## Acceptance Criteria

- `./gate.sh` passes at the end of each accepted implementation slice.
- Verification tests prove the pure verify path uses the dedicated
  `mpfs-verify-reactor.wasm` boundary and parses `verify_ok` / `verify_error`
  verdicts.
- Unit tests cover csmt-utxo response decoding, root/proof matching by
  `{slotNo, blockHash}`, neutral verifier result handling, datum/facts-root
  comparison, and UI state transitions for verified and mismatch outcomes.
- The Facts tab exposes both the existing proof verification verdict and the
  second-oracle verdict for the selected token.
- The final PR body links issue #33 and parent #34 and states the live service
  used for the oracle client.

## Non-Goals

- Do not modify `cardano-mpfs-offchain`, `cardano-utxo-csmt`, or the deployed
  csmt-utxo service.
- Do not produce or submit UTxO roots from the browser.
- Do not replace Haskell/WASM verifier behavior with PureScript or JavaScript
  protocol implementations.
- Do not redesign the #32 Halogen app shell or write flows outside the files
  needed for the verify/oracle feature.
