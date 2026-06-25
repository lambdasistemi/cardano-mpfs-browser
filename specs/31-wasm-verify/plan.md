# plan — #31

## Tech stack
PureScript + spago (`mpfs-explorer`), Halogen, esbuild bundle (`spago bundle` →
`dist/index.js`), nix flake. Gate: `nix develop -c just ci` (build + bundle + test
against Haskell `cage-test-vectors`) + `just lint` (purs-tidy).

## Slice (one bisect-safe commit)

### Slice 1 — replace PureScript/JS verification with the WASM cage reactor
- **Wasm asset**: wire `cardano-mpfs-offchain.packages.${system}.wasm-mpfs-verify`
  (already a flake input) so `mpfs-cage-reactor.wasm` lands as a bundled asset (mirror
  how `cardano-mpfs-offchain`'s `nix/mpfs-spa.nix` passes `cageReactorWasm` and how
  `mpfs-spa`'s `bootstrap.js` imports `./assets/mpfs-cage-reactor.wasm`).
- **Reactor FFI**: port `MpfsSpa/CageHelpers/Reactor.js` (loader: `WebAssembly.instantiate`
  / `instantiateStreaming`) + `Reactor.purs` (`runCageReactor`, the JSON-envelope→stdout
  interface) into the browser (e.g. `MPFS/Reactor.{purs,js}`).
- **Reroute verify**: replace `MPFS.Proof.CSMT.decodeAndVerify` (and the MPF verify) call
  sites with a reactor verify call (marshal the proof into the envelope, parse
  verify_ok/verify_error).
- **Delete**: `MPFS/Proof/CSMT.purs`, `MPFS/Proof/CSMT/Cbor.{purs,js}`,
  `MPFS/Proof/MPF.purs`, `MPFS/Proof/MPF/Bytes.purs`, `MPFS/Proof/MPF/Merkle.purs`,
  `MPFS/Crypto/Hash.purs` (+ its FFI); remove `@noble/hashes` from `package.json`.
- **Tests**: the `cage-test-vectors` suite now exercises the wasm path; keep it green.

Single vertical slice: the verify path PS→wasm replacement is one coherent, bisect-safe
change. If the wasm-asset bundling proves large, the driver may split asset-wiring from
the reroute and log it in WIP.md.
