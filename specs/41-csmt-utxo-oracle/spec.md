# Issue #41: CSMT UTxO Second Trust Oracle

## P1 User Story

As an MPFS user, the browser independently confirms the selected MPFS token
anchor UTxO is present in the Cardano UTxO set at a csmt-utxo chainpoint and
shows that verdict next to the existing MPFS proof verdict, without trusting the
MPFS offchain service and without running a node.

## Context

The browser already routes MPFS fact proof verification through the Haskell WASM
verify reactor. This ticket adds the second trust oracle: the deployed
`https://utxo-csmt.plutimus.com` service supplies chainpoint-keyed CSMT roots and
inclusion proofs, and the browser verifies those proofs through the neutral
`csmt-verify-wasm` artifact from `cardano-mpfs-offchain`.

The neutral verifier is not the existing MPFS JSON-envelope reactor. It consumes
binary stdin bytes:

```text
[opcode 0=inclusion][32-byte trusted root][CBOR proof]
```

and reports the verdict only through the WASI exit code. Exit 0 means verified;
exit 1 means not verified or malformed.

## Functional Requirements

- FR-001: The browser flake input for `cardano-mpfs-offchain` is repinned to
  revision `a20656e` and `just prepare-wasm` bundles
  `csmt-verify-wasm.wasm` from the existing `.#wasm-mpfs-verify` output.
- FR-002: A separate CSMT verifier runner feeds binary stdin to
  `csmt-verify-wasm` and exposes an inclusion verifier that accepts
  hex-encoded root and proof bytes and returns a boolean verdict.
- FR-003: A csmt-utxo client decodes `GET /merkle-roots` responses with
  `{slotNo, blockHash, merkleRoot}` entries and `GET /proof/:txId/:txIx`
  responses with `{slotNo, blockHash, proof, txOut}`.
- FR-004: For the selected MPFS token output reference, the app fetches the
  CSMT proof and matching chainpoint root, verifies inclusion through the WASM
  verifier, decodes the attested `txOut` datum, and compares its MPFS facts root
  to the MPFS service's token root.
- FR-005: The UI renders a second-oracle status with verified, mismatch, and
  unavailable/failure states, and resets that state when selected token facts
  are refreshed or changed.
- FR-006: Unit tests use captured real csmt-utxo fixtures for deterministic
  positive and tampered negative coverage. A live csmt-utxo smoke is documented
  as an operator follow-up, not a CI gate.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- A captured real `{root, proof}` verifies through bundled
  `csmt-verify-wasm`, and a tampered proof/root fails closed.
- Captured csmt-utxo JSON fixtures decode and malformed variants are rejected.
- Verdict tests cover verified, mismatch, and unavailable paths.
- The Facts view shows the second-oracle verdict for the selected token.
- The PR links `Closes #41` and parent `#34`.

## Non-Goals

- Do not implement CSMT verification in JavaScript or PureScript.
- Do not change `src/MPFS/Reactor.*`, `src/MPFS/Cage*`, `flake.nix`, the
  offchain repository, or the deployed csmt-utxo service.
- Do not make live `utxo-csmt.plutimus.com` availability part of CI.
