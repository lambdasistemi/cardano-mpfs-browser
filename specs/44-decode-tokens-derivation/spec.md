# Issue #44: Derive Token IDs From Real `/tokens` TxOuts

## User Story

As an MPFS explorer user, I can load the real token list from the live
`umpfs.plutimus.com` backend, select a token, load its facts, and continue into
the verification flow without the client failing on non-empty token entries.

## Context

`MPFS.Client.decodeTokensBody` currently accepts only the trivial
`tokens.entries: []` response and returns a hardcoded decode error for every
non-empty response. The previous e2e fixture used an empty token set, so CI
stayed green while the real backend response was impossible to decode.

The live `GET https://umpfs.plutimus.com/tokens` response carries each token as
an entry with `txout_cbor`. The token id is the 32-byte asset name under the
MPFS cage policy in that TxOut's value.

The captured fixture for this ticket is:

- `/tmp/mpfs44/ticket/answers/real-umpfs-tokens.json`

It contains two live entries and must be copied into `test/fixtures/` by the
implementation slice. Tests based only on `entries: []` do not satisfy this
ticket.

## Functional Requirements

- FR-001: `decodeTokensBody` decodes non-empty `tokens.entries` responses.
- FR-002: Each returned token id is derived from `entries[].txout_cbor` by
  decoding the Cardano TxOut and taking the asset name from the MPFS cage asset.
- FR-003: The real two-entry `umpfs` fixture is committed under
  `test/fixtures/` and a `just ci` test asserts the derived ids:
  - `976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6`
  - `98207724b0ea59b96c0eba16cb09e91da10f8bdc54ad36da4a2e40104a59a32b`
- FR-004: Empty `entries` remains a valid response and decodes to `[]`.
- FR-005: A live-boundary smoke hits `https://umpfs.plutimus.com/tokens`,
  decodes through the real PureScript client path, and fails unless at least one
  token id is derived.
- FR-006: Operator-facing backend references use `umpfs.plutimus.com`, not the
  stale `mpfs.plutimus.com` backend.

## Non-Goals

- No support for the deprecated top-level array or stale `mpfs.plutimus.com`
  response schema.
- No reactor rewrites, SecondOracle internals changes, wallet write-flow
  changes, dependency bumps, or flake pin changes.

## Acceptance Criteria

- The real non-empty fixture test runs as part of `just ci`.
- `./gate.sh` runs lint, `just ci`, the devnet e2e recipe, and the live `umpfs`
  token smoke.
- The PR body names the live smoke artifact and closes #44 under parent #34.

## A-002 Correction: Read Flow Must Match Real UMPFS

The first branch walk proved token listing works, but "Load facts" still failed
against live `umpfs` with `Decode error: (AtKey "max_fee" MissingValue)`. The
current offchain API returns token state as raw UTxO:

```json
{"snapshot": {...}, "state": {"utxo": {"tx_in": {...}, "tx_out": "..."}}}
```

The state fields are in the inline datum inside `utxo.tx_out`; the API does not
emit JSON `max_fee`, `process_time`, or `retract_time`. This ticket therefore
also requires the browser read flow to decode real `/tokens/:id` and
`/tokens/:id/...` responses end to end:

- `/tokens/:id`: decode `state.utxo.tx_out` inline datum into `TokenState`.
- `/tokens/:id/facts`: keep real `facts` decoding and include a real fixture so
  the state envelope cannot hide drift.
- `/tokens/:id/root`: continue decoding the real quoted root response.
- `/tokens/:id/requests`: decode the real response shape using live request UTxO
  data, not a fictional fixture-only contract.

Required real fixtures:

- `/tmp/mpfs44/ticket/answers/real-umpfs-token-state.json`
- `/tmp/mpfs44/ticket/answers/real-umpfs-facts.json`
- live-captured root and requests fixtures for the same real token.

## A-003 Correction: Second Oracle Must Be Reachable

The A-002 live walk proved the read flow now loads state, pending requests,
facts, and root from real `umpfs` data. The remaining #44 acceptance path still
does not run because `App.selectedTokenOutputRef` returns `Nothing` for every
state:

```purescript
selectedTokenOutputRef :: AppState -> Maybe OutputRef
selectedTokenOutputRef _ = Nothing
```

That keeps `SecondOracle.checkOutputRef` unreachable from the running app and
turns the `csmt-utxo` integration into dead code.

This ticket therefore also requires:

- `decodeTokenBody` must preserve the current token output reference from
  `state.utxo.tx_in`.
- `selectedTokenOutputRef` must return that selected token current output
  reference after token state is loaded.
- The real second-oracle path must be tested with live data:
  `umpfs.plutimus.com` selected token state/root plus
  `utxo-csmt.plutimus.com` proof/roots and the real WASM verifier. A mock
  verifier does not satisfy this acceptance condition.
