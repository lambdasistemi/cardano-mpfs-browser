# Issue #48: CSMT Second Oracle Real Verify Anchor

## P1 User Story

As an MPFS user, the "Second oracle: Verified" badge means the browser has run
the real `csmt-verify-wasm` inclusion verifier against the selected token UTxO's
captured `utxo-csmt` proof and chainpoint root. If the proof, served root, or
datum facts root does not match, the UI shows mismatch instead of verified.

## Context

Issue #41 added the csmt-utxo second oracle and live rendering. This ticket is
the trust-anchor hardening for epic #47: it must prove that the positive badge is
not a soft/default path and that a negative case is a distinct verdict.

The project already has a live preprod fixture at
`test/fixtures/csmt-utxo-verdict-real-mpfs-token.json`. The hardening must drive
the full verdict path with that fixture and `MPFS.SecondOracle.CsmtVerify`'s real
`verifyInclusion`, not a mocked boolean, for both verified and mismatched cases.

## Functional Requirements

- FR-001: The domain verdict distinguishes exactly the user-facing classes:
  verified, mismatch, and unavailable/failure. A verifier false result from a
  tampered proof or wrong chainpoint root is a mismatch, not verified and not a
  soft unavailable state.
- FR-002: `checkOutputRef` continues to call the injected
  `verifyInclusion` dependency with the chainpoint-matched root and served proof;
  the app dependency remains `CsmtVerify.verifyInclusion`.
- FR-003: A facts-root mismatch between the MPFS token root and the attested
  datum root returns the mismatch verdict with both roots preserved for
  debugging.
- FR-004: Real-data tests use
  `test/fixtures/csmt-utxo-verdict-real-mpfs-token.json` and real
  `CsmtVerify.verifyInclusion` through the full verdict path:
  - original fixture -> verified,
  - tampered proof -> mismatch,
  - mismatched expected datum root -> mismatch.
- FR-005: UI status labels render verified and mismatch distinctly, and do not
  present tampered proof / wrong root as "Verified" or as a generic unavailable
  state.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- The real preprod fixture's original proof/root produces `Second oracle:
  Verified` through the real verifier path.
- A tampered proof or wrong root produces the mismatch verdict and UI label.
- A datum facts-root mismatch produces the mismatch verdict and UI label.
- No mocked-verifier positive/negative test is the only proof for this ticket.
- The PR links `Closes #48` and parent `#47`.

## Non-Goals

- Do not change `src/MPFS/Reactor.*`, `src/MPFS/Cage*`, the Haskell reactor, or
  the `csmt-verify-wasm` artifact.
- Do not implement CSMT verification in JavaScript or PureScript.
- Do not implement facts proofs 2-5 from epic #47.
- Do not make live `utxo-csmt.plutimus.com` availability a CI dependency; the
  epic owner performs the final live browser tamper walk.
