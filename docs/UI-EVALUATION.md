# UI/UX Evaluation: cardano-mpfs-browser SPA

Evidence used: `/tmp/uieval/brief.md`, `src/MPFS/App/View.purs`, `src/App.purs`, `src/MPFS/App/Facts.purs`, `src/MPFS/Client*.purs`, `src/MPFS/Cage/Wasm.purs`, `dist/index.html`, screenshots `/code/moog/final-connect.png`, `/code/moog/final-tokens.png`, `/code/moog/final-facts.png`, and sibling references in `purescript-spa-kit/mui`, `cardano-mpfs-offchain-ui-redesign/mpfs-spa`, `cquisitor`, and `cardano-ledger-inspector`. No browser MCP was available.

## 1. Executive Summary

- The current SPA is functionally wired but visually still a placeholder. It uses one generic two-column panel for every workflow, so token/fact/request management has weak hierarchy and poor action guidance.
- The operator's overflow complaint is confirmed. In `final-facts.png`, request values sprawl far beyond the panel and screenshot width because request/fact rows render raw hex in unbounded flex spans.
- Requests are the largest UX failure. The UI shows operation/key/value/phase only; it does not clearly show requester, request id, age/deadlines, proof coverage, or who may retract.
- Hash/key/value handling needs a first-class component: show `xxxx…yyyy`, keep full value in tooltip/title/detail, and provide one-click copy with copied feedback.
- Recommendation: choose path A. Keep Halogen and implement the house Material design language with Halogen components plus plain CSS. Do not adopt react-basic+MUI for this asset-managing app.
- Use the redesigned `mpfs-spa` and `purescript-spa-kit/mui` as design/behavior references, not as runtime dependencies. The current app has 1 runtime npm package; the MUI sibling has 86.

## 2. Findings

| Severity | Where | What's wrong | Why it matters |
|---|---|---|---|
| Critical | Facts screenshot `final-facts.png`; `src/MPFS/App/View.purs:725`; `dist/index.html:200` | Pending requests render as `ul.token-list > li` flex rows with raw `key` and `value` spans. The long value span has no truncation, copy affordance, or constrained width, so it stretches past the panel. | The core request management view becomes unreadable. Users cannot compare or safely act on pending changes. |
| Critical | `src/MPFS/App/View.purs:725`; `src/MPFS/Client/Types.purs:77` | Request rows omit request id, requester/owner, fee, submitted time, deadline, and proof coverage, despite those fields existing in the decoded model. | A user cannot tell what the request will do, who made it, whether it is trustworthy, or which row a transaction will consume. |
| High | `src/MPFS/App/View.purs:764`; `src/MPFS/App/Facts.purs:148`; reference `mpfs-spa/src/MpfsSpa/App.purs:1469` | `Retract` is always rendered for every request. The current UI does not gate or explain that only the requester can retract, and only during the retract window. | The UI invites invalid transactions and fails to explain the protocol's authority model. |
| High | `src/MPFS/App/View.purs:753`; `src/App.purs:405`; `src/App.purs:419`; reference `mpfs-spa/src/MpfsSpa/App.purs:1379` | Any request can be selected, and `Process selected` / `Reject expired` only require a non-empty selection in the app action. The Material reference checks that all selected rows are in the right phase. | Users can build/sign transactions that are predictably invalid or semantically wrong. |
| High | `src/MPFS/App/View.purs:925`; `src/MPFS/App/View.purs:786`; `src/MPFS/App/View.purs:773` | `shortText = identity`, and token/fact/request values render raw. There is no copy-to-clipboard path in the view actions. | Long identifiers dominate the screen, cannot be copied reliably, and make visual scanning impossible. |
| High | `src/MPFS/App/View.purs:193`; `src/MPFS/App/View.purs:598` | The Facts tab puts token state, trusted roots, requests, facts, lookup, write forms, verification, and global actions into one long generic panel. | Token/fact management feels like a dump of internal state rather than a workflow. |
| High | `src/App.purs:241`; `src/MPFS/App/View.purs:156` | Selecting a token only updates state; it does not guide the user to Facts or load facts. Tokens are a list of raw IDs plus two buttons. | The main path "load tokens -> select token -> load facts -> process requests" is not discoverable. |
| Medium | `src/MPFS/App/View.purs:195`; `src/MPFS/App/View.purs:286` | Verification statuses are presented as generic field cards: "Facts set Verified", "Pending requests: Verified", "Second oracle Verified". | Users see "Verified" but not what was verified, at which snapshot, by which proof, or what would make it unsafe. |
| Medium | `src/MPFS/App/View.purs:550`; `src/App.purs:446`; spec `specs/49-per-fact-mpf-inclusion/spec.md:60` | Fact lookup now auto-verifies looked-up facts in code, but the UI still prominently asks for a manual "Proof envelope". | The proof model looks manual and obscure even when the happy path is automatic. |
| Medium | `dist/index.html:7`; `src/MPFS/App/View.purs:545`; `src/MPFS/App/View.purs:598` | `dist/index.html` styles panels/buttons/lists but not `.field-group`, `input`, or `textarea`. In `final-facts.png`, bottom forms fall back to native browser controls. | The most important write controls look least integrated and are harder to scan. |
| Medium | `dist/index.html:122`; reference `mpfs-spa/src/MpfsSpa/App.purs:1225`; reference `mpfs-spa/src/MpfsSpa/App.purs:1317` | The current panel has no bounded table/list regions. The Material reference uses table containers and sticky headers for facts/requests. | Long request/fact lists create a very tall page and bury actions at the bottom. |
| Medium | `dist/index.html:8`; reference `purescript-spa-kit/mui/src/SpaKit/MUI.js:146`; reference `mpfs-spa/src/MpfsSpa/App.purs:409` | The app palette is beige/teal/magenta and does not match the house MUI theme vocabulary of neutral background, primary blue, success/warning chips, dense Paper/Table/Card structure. | It does not yet read as the same family as the sibling browser tools. |
| Medium | `src/App.purs:639`; `src/App.purs:642`; `src/MPFS/App/View.purs:835` | Write flow status moves from built to wallet signing without a decoded transaction intent review screen. | For an asset-managing app, users need to see what they are about to sign, not just "Waiting for wallet signature". |
| Low | `src/MPFS/App/View.purs:162`; `src/MPFS/App/View.purs:188`; `src/MPFS/App/View.purs:248` | Tab names are coarse, while the actual workbench is mostly token/fact/request management. | The app can be clearer with a persistent token list plus workspace sections instead of treating each workflow as a separate page. |

Overflow/clipping/no-wrap inventory:

- Confirmed page overflow: request value spans in `requestRow` (`View.purs:737-738`) inside flex `li` rows (`dist/index.html:200-206`).
- Likely same failure: fact values in `factRow` (`View.purs:776-777`) because the value span is not wrapped/truncated.
- Current long token/root/owner fields mostly wrap because `.field-line strong` uses `overflow-wrap:anywhere` (`dist/index.html:77-83`), but they should still be truncated/copyable rather than wrapped into multi-line blocks.
- Token rows use `overflow-wrap:anywhere` (`dist/index.html:211-220`), so they do not explode the page, but they are not scan-friendly or copyable.
- Inputs and textareas have no app-level styling; pasted long proof JSON should be contained in a monospace, scrollable proof panel rather than a plain textarea.

## 3. The MPFS Request/Proof/Retract Model

An MPFS request is a pending on-chain fact operation for a selected token. It is created by a requester and contains:

- `request_id`: the request UTxO reference (`txid#ix`), derived in `src/MPFS/Client.purs:539`.
- `owner`: the requester/owner key hash from the request datum (`src/MPFS/Client.purs:532-539`).
- `operation`: `insert`, `update`, or `delete`, derived from the request datum (`src/MPFS/Client.purs:564-573`).
- `key`, `value`, `fee`, and `submitted_at` (`src/MPFS/Client/Types.purs:77-87`).

The request set is proof-bearing. The browser preserves the raw `/tokens/:id/requests` response (`src/MPFS/Client.purs:435-459`), independently anchors its snapshot root against the second oracle (`src/MPFS/App/Verification.purs:163-184`), then calls the WASM verifier with `op = verify_snapshot` (`src/MPFS/App/Verification.purs:236-263`). The UI should say "Request set verified" and expose proof details: snapshot slot, trusted root, verifier op, verdict, and raw proof/envelope copy.

The request phase is computed from token timing:

- `processable`: `now - submitted_at <= process_time`
- `retractable`: after process time, until `process_time + retract_time`
- `expired`: after both windows

That logic is in `src/MPFS/App/Facts.purs:148-158`. The UI must make authority explicit: the requester can retract during the retract window. Processing belongs to the token/agent path for processable requests; rejecting belongs to expired requests. A row should show both the row's requester and whether the connected wallet is "you", then enable only the actions the connected wallet and phase allow.

## 4. Redesign Proposal: House Material Style

Keep the first screen as the actual workbench, not a landing page. Use a Material-like app shell, but implement it in Halogen and CSS:

```text
+-----------------------------------------------------------------------+
| MPFS Browser                              Wallet chip | Network | API |
+----------------------------+------------------------------------------+
| Tokens                     | Token 976821db…aaacbc6     Verified chips |
| [Refresh] [Register]       | owner 8da87507…526f0c9f (not you)        |
| [Mine only toggle]         +------------------------------------------+
| > 976821db…aaacbc6  Mine   | Facts                                    |
|   98207724…59a32b Read     | Key        Value              Actions    |
|                            | schema…   7b2261…7d       [edit][delete]|
|                            +------------------------------------------+
|                            | Pending Requests                         |
|                            | [Process selected] [Reject expired]      |
|                            | Op  Key  Value  Requester  Phase Actions |
|                            | Ins cfg  {...}  you        Expired       |
+----------------------------+------------------------------------------+
```

Concrete components:

- App shell: `top-app-bar`, `token-sidebar`, `workspace`, `section-header`, `paper`, `table`, `status-chip`, `alert`, `dialog`, `icon-button`.
- Theme tokens: copy the visual language from `purescript-spa-kit/mui` and `mpfs-spa`: neutral `#f7f8f9` background, white paper, primary `#255f85`, success `#2f6f50`, warning `#b46a1c`, 6px radius, dense spacing.
- Tokens: persistent left rail with selected row, owner chip, "Mine" / "Read-only", refresh/register icons, empty states with next action. Do not require the user to remember to switch tabs after selecting.
- Facts: table with bounded height and sticky header. Columns: decoded key label, key hash chip, decoded value/summary, value hash chip, proof status, actions. Use dialogs for insert/update/delete instead of three always-visible raw forms.
- Requests: table on desktop, stacked cards on mobile. Columns: select, operation chip, key, value, requester, age/deadline, phase, proof, actions. The row title should read like "Insert cfg -> <value summary>", not raw concatenated text.
- Request cards on mobile:

```text
[Insert] [expired] [request set verified]
Key      7b227479…6669677d  [copy]
Value    7b226167…317d7d    [copy]
Requester 8da87507…526f0c9f (you)
Submitted 2h 14m ago | Process window ended | Retract window ended
Actions: disabled with reason, or Retract when requester + retractable
```

- Proof detail: a collapsible drawer/dialog per request set and per fact lookup. Show:
  - verifier verdict chip
  - snapshot slot and root
  - trusted root source
  - verifier operation (`verify_snapshot`, `verify_fact_inclusion`, etc.)
  - raw proof/envelope with copy/download
  - failure reason when rejected
- Hash chip pattern: render full values as `front…back`, e.g. `7b227479…6669677d`. Use monospace text, max-width, `overflow:hidden`, and a visible copy button. Hover/focus can show a tooltip with the full value; click copies full value. CQuisitor's pattern is the right behavior reference (`HashWithTooltip.tsx:17`, `CopyButton.tsx:11`, `globals.css:7394`, `globals.css:8998`).
- Overflow handling:
  - No raw hash should be a bare flex item.
  - Every table cell containing untrusted or user-provided bytes must use `min-width:0`.
  - Desktop tables may scroll horizontally inside their own container; the page itself should not.
  - Mobile request/fact cards should stack fields and use chips, not tables squeezed below readability.

## 5. Framework Recommendation

Recommend A: keep Halogen; implement the Material design language in Halogen + CSS.

Rationale:

- Trust boundary wins for this app. `cardano-mpfs-browser` is asset-managing and signs/submits wallet transactions. Its current runtime npm tree is one package: `@bjorn3/browser_wasi_shim`. The redesigned React+MUI `mpfs-spa` lockfile has 86 runtime packages, including MUI, Emotion, React, and transitive Babel/utility packages.
- The existing project spec already points this way: `specs/32-port-mpfs-spa/spec.md:12-21` says the target architecture is Halogen with a small npm runtime surface and that `mpfs-spa` is reference behavior only; `specs/32-port-mpfs-spa/spec.md:42` explicitly excludes react-basic, MUI, and Emotion.
- Exact MUI component reuse is not worth increasing the signing-page JS surface. A compromised presentation dependency can alter what the page asks the wallet to sign.
- Visual consistency does not require importing MUI. The Material language is mostly layout, density, typography, color tokens, elevation/borders, chips, tables, dialogs, and icon-button patterns. Those are straightforward in Halogen/plain CSS.
- Effort is moderate but bounded. The current UI is centralized in `src/MPFS/App/View.purs` and one inline CSS block. Rebuilding a small Halogen component kit is less risky than moving the app back to React or embedding React islands.

What to reuse:

- From `purescript-spa-kit/mui`: the component vocabulary and theme constants, not the MUI bindings.
- From `cardano-mpfs-offchain-ui-redesign/mpfs-spa`: the two-pane workbench, token ownership filtering, owner chips, request/fact tables, phase chips, dialogs, and action gating ideas.
- From CQuisitor: truncating/copyable hash chips and proof/detail inspection patterns.
- From `cardano-ledger-inspector`: Halogen clipboard/action patterns for copied state.

When B would be acceptable:

- Only for a read-only inspector or demo surface that never requests wallet signatures, or if the organization explicitly relaxes the asset-app npm boundary. For this SPA, B should not be chosen.

## 6. Proposed Implementation Breakdown

1. Foundation ticket: add Halogen/plain-CSS Material primitives.
   - Components: `Button`, `IconButton`, `Chip`, `StatusChip`, `HashChip`, `CopyButton`, `Paper`, `SectionHeader`, `DataTable`, `Dialog`, `Alert`.
   - Add clipboard FFI and copied feedback.
   - Move CSS out of inline-only growth if desired, but keep zero runtime CSS/JS dependencies.

2. Overflow and hash ticket.
   - Replace `shortText = identity` with a real middle truncation helper using the required `xxxx…yyyy` display.
   - Use `HashChip` for token IDs, owners, roots, request IDs, keys, values, tx IDs, proof roots, and submitted transaction IDs.
   - Add screenshot/golden checks with long request values.

3. App shell and responsive layout ticket.
   - Replace tab-centric page flow with top app bar + token sidebar + workspace.
   - Preserve mobile as single-column: token selector first, workspace below.
   - Keep Connect/End workflows reachable but not dominant.

4. Token management ticket.
   - Add ownership chips, "Mine only" filter, selected token summary, refresh/register actions, and clear empty states.
   - After selecting a token, load or prompt to load facts in the workspace.

5. Facts management ticket.
   - Replace raw fact list with a bounded table/card layout.
   - Use dialogs for insert/update/delete.
   - Show pending-change blockers per fact when a request exists for that key.

6. Pending request UX ticket.
   - Render request table/cards with operation, key, value, requester, request id, fee, submitted age, process/retract deadlines, phase, proof status, and permitted actions.
   - Gate selection/actions by phase and connected wallet authority.
   - Show disabled reasons in tooltips or helper text.

7. Proof inspector ticket.
   - Add request-set and per-fact proof detail views.
   - Surface snapshot slot/root, trusted root, verifier op, raw proof/envelope copy, and rejection messages.
   - De-emphasize manual proof-envelope paste; keep it under an advanced section if still needed.

8. Transaction intent/review ticket.
   - Before CIP-30 signing, show decoded operation intent: token, request id(s), fact key/value changes, requester/agent role, fees, inputs/outputs/proof statuses.
   - Make wallet signing a deliberate final action from that review.

9. Accessibility/responsive verification ticket.
   - Keyboard reachability for tables, dialogs, copy buttons, and action menus.
   - Viewport checks around 360px, 720px, 1280px, and long-value fixtures.
   - Assert no page-level horizontal overflow; only intended local table/proof scroll areas may scroll.
