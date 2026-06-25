# tasks — #31

## Slice 1 — replace PureScript/JS verification with the WASM cage reactor
- [ ] T31-S1 Bundle `mpfs-cage-reactor.wasm` (from the existing `cardano-mpfs-offchain` flake input `wasm-mpfs-verify`) as a browser asset; port the reactor loader (`Reactor.js`) + `runCageReactor` (`Reactor.purs`) from mpfs-spa; reroute proof verification through the reactor; delete `MPFS/Proof/*` + `MPFS/Crypto/Hash` + `@noble/hashes`; `just ci` + `just lint` green via the wasm path.
