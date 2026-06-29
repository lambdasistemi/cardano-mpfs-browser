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
