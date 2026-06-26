# Issue #36: Adapt `/tokens` Decoder

## User Story

As an MPFS explorer user, I can query `/tokens` against the same-revision
devnet server introduced by the #31 offchain flake bump and the browser client
decodes the response without a `TypeMismatch "Array"` failure.

## Context

Issue #31 needed an offchain revision that exposes `wasm-mpfs-verify`. That
same revision also changed the `mpfs-devnet-server` `/tokens` response shape.
The explorer client still expects the old top-level JSON array and now fails in
`MPFS.Client` when the e2e suite exercises `GET /tokens`.

This ticket is a narrow regression fix. It must not revert the offchain bump
and must not expand into the larger Halogen app port, verify reactor work, or
other API endpoints unless the same `/tokens` shape requires a local helper.

## Functional Requirements

- FR-001: `Client.getTokens` decodes the bumped devnet server's actual
  `GET /tokens` JSON response shape.
- FR-002: The client preserves the public result expected by callers: an
  `Array TokenId` for the known token identifiers.
- FR-003: A test covers the new JSON shape directly so future server response
  drift fails before the live e2e boundary.
- FR-004: The e2e `GET /tokens` test passes against the same-revision
  `mpfs-devnet-server` launched by `just e2e`.

## Non-Goals

- No changes to verify reactor wiring, WASM assets, transaction CBOR, app UI, or
  unrelated endpoints.
- No dependency or flake revision changes.
- No weakening or skipping of the existing e2e client tests.

## Acceptance Criteria

- `test/Test/MPFS/ClientSpec.purs` contains a RED-first assertion that fails on
  the old top-level-array decoder and describes the bumped `/tokens` response.
- `src/MPFS/Client.purs` and/or `src/MPFS/Client/Types.purs` decode the new
  response while keeping `getTokens :: Aff (Either ClientError (Array TokenId))`.
- `./gate.sh` completes successfully, including the e2e `/tokens` proof.
