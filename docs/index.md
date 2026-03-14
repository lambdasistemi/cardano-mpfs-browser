# MPFS Explorer

A PureScript browser application for exploring MPFS facts and
verifying Cardano transactions without trusting the off-chain service.

## Goals

1. **Fact exploration** — browse token facts with schema-driven
   rendering, verified end-to-end via Merkle proofs
2. **Untrusted transaction verification** — decode unsigned
   transactions in MPFS semantics so users never blindly sign
3. **Fully off-chain verification** — prove fact existence without
   a Cardano node, using institutional UTXO Merkle roots

## Documentation

- [Design](design.md) — architecture, trust model, UX flows
