# MPFS Browser — Design Specification

A web workbench for inspecting on-chain **MPFS (Merkle Patricia Forest Store)** data
and its cryptographic verification, and for submitting changes with a CIP-30 wallet.

Built as a Material-3-flavored, hand-rolled component set in plain HTML/CSS so it
ports directly to **PureScript/Halogen** (no React/MUI/Tailwind runtime).

- **Entry point:** `MPFS Browser.dc.html`
- **Reusable component:** `HashChip.dc.html` (copyable, middle-truncated identifier)

---

## 1. Product principles

1. **Data + its verification is the star.** Everything secondary (network, wallet,
   endpoint) is demoted to the chrome.
2. **Read without a wallet.** Tokens, facts, requests, and proofs are fully
   browsable with no wallet. A wallet gates only *submit* and *retract*.
3. **No raw hex walls.** Every long identifier is a copyable, middle-truncated chip
   (`xxxx…yyyy`). Fact keys/values are shown **decoded to UTF-8 JSON**.
4. **Signing is deliberate.** Writes always route through a decoded intent review
   before the wallet prompt.
5. **No page-level horizontal overflow at any width.** Long bytes live in bounded
   chips; tables scroll inside their own container only.

---

## 2. Design tokens

### Color (light surface — default)

| Role | Value | Usage |
|---|---|---|
| `surface` | `#eceef2` | App background |
| `surface-container` | `#f6f7f9` | Sidebar, table headers, code wells |
| `surface-bright` | `#ffffff` | Cards, app bar, table body |
| `outline` | `#e2e6ec` | Card / table borders |
| `outline-strong` | `#c6ccd5` | Input borders |
| `on-surface` | `#191c20` | Primary text |
| `on-surface-variant` | `#5b636e` | Secondary text |
| `on-surface-dim` | `#8a919c` | Tertiary / captions |
| `primary` | `#2264d1` | Primary accent, actions, active nav |
| `primary-hover` | `#1b57bd` | Primary pressed/hover |
| `primary-container` | `#eaf1fd` / text `#123a86` | Wallet chip, active token, key labels |
| `success` | `#1f8a4c` / bg `#e2f3e8` / text `#0b5a2e` | Verified verdicts, INSERT, PASS |
| `warning` | `#a9680c` / bg `#f8ecd4` / text `#6e430a` | Retractable, pending proof |
| `error` | `#c0362c` / bg `#fadedb` / text `#7a1c16` | DELETE, retract action |
| `neutral-chip` | bg `#eceef2` / text `#5b636e` | Expired phase, counts |

### Dark surface (tokens — noted for Halogen theme swap)

| Role | Value |
|---|---|
| `surface` | `#14171c` |
| `surface-container` | `#1b1f25` |
| `surface-bright` | `#21262d` |
| `outline` | `#2b323b` |
| `on-surface` | `#e6e9ee` |
| `on-surface-variant` | `#aeb6c2` |
| `primary` | `#4dabf7` |
| `success` | `#51cf66` |
| `warning` | `#f0a63c` |
| `error` | `#ff6b5e` |

Status chip fills in dark mode use ~14% alpha of the hue over `surface-container`.

### Spacing scale
`2 · 4 · 6 · 8 · 10 · 12 · 14 · 16 · 20 · 24 · 32` px. Dense by default; card padding
`12–18px`, table cell padding `9–14px`.

### Radius
- Chips / inputs / buttons / cards: **6px**
- Pills (verdict, phase, network): **12–20px** (fully rounded)
- Avatars / status dots: **50%**

### Type scale (Roboto / Roboto Mono)
| Token | Size / weight | Usage |
|---|---|---|
| `display` | 20px / 700 | Page title ("Token") |
| `title` | 17px / 700 | Verdict card heading |
| `subtitle` | 15px / 500 | Metric values |
| `body` | 13px / 400 | Table cells, controls |
| `label` | 12px / 500 | Secondary labels |
| `caption` | 11px / 400 | Deadlines, hints |
| `overline` | 11px / 600, `.5px`, uppercase | Column headers, metric labels |
| `mono` | Roboto Mono 12–13px | All hashes, JSON, slots |

### Elevation
- Level 0: borders only (`1px solid outline`) — the default for cards/tables.
- Level 1: `0 1px 2px rgba(0,0,0,.25)` — toggle knob, floating chips.
- Drawer/dialog scrim: `rgba(20,23,28,.45)` + panel shadow `0 8px 32px rgba(0,0,0,.24)`.

---

## 3. Layout

Desktop (**1440**): sticky app bar → two-column grid `300px | 1fr`.
- **Left token sidebar:** search, "Owned by me" toggle, scrollable token list
  (each row: kind dot, `xxxx…yyyy` id, MINE badge, facts + pending counts).
- **Right workspace:** token header (id chip, owner chip, verdict pill) → 4-up
  summary strip (state root, max fee, process window, retract window) → tab bar
  (Facts / Pending / Verification) → active panel. Max content width `1160px`.

Tablet (**768**): sidebar narrows; summary strip wraps to 2-up; tables keep their
own horizontal scroll container.

Mobile (**390**): sidebar collapses to a token **picker** pinned on top; workspace
stacks single-column; Pending rows render as **stacked cards** instead of a table;
summary strip becomes a 2-col grid.

---

## 4. Screens & journeys

1. **First run / connect** — read-only browsing is live immediately. A single
   explanatory banner states what MPFS Browser does and that a wallet is only for
   writes. No dead-ends; "Connect wallet" is available but never blocking.
2. **Tokens (registry)** — scannable sidebar list; search by id/owner; "Mine"
   filter; selecting a token loads its workspace inline (no route change feel).
3. **Facts** — bounded, scrollable table. Each row: decoded key **label** + copyable
   key JSON well, decoded value JSON well (scrolls if tall), inclusion proof chip,
   row actions (Proof, Edit-if-mine). Dimmed empty state when the forest is empty.
4. **Pending requests** — table (desktop) / cards (mobile). Each row: op chip
   (INSERT/UPDATE/DELETE), decoded key→value, requester chip + **YOU** badge, age,
   fee, **phase chip** (Processable → Retractable → Expired), proof chip, and a
   **Retract** action gated by phase + authority.
5. **Verification / proof inspector** — persistent verdict card listing the three
   checks (second-oracle agreement, facts-set completeness, per-fact inclusion
   proofs) with snapshot slot, trusted root, verifier op; a **proof drawer** opens
   per-fact and per-set with raw proof (copy/download) and a failure reason on reject.
6. **Write dialogs + intent review** — insert/update/delete/retract in a dialog:
   edit → **decoded "what you're about to sign" review** → sign (CIP-30) → done.

---

## 5. Component inventory (states)

| Component | States |
|---|---|
| **Button** (primary / outline / text / danger) | default · hover · focus · disabled (with reason) · loading (spinner) |
| **Hash chip + copy** | default · hover · copied (✓, 1.2s) — `xxxx…yyyy`, optional label |
| **Status / phase chip** | processable (blue) · retractable (amber) · expired (neutral) · verified (green) · pending (amber) |
| **Op chip** | insert (green) · update (blue) · delete (red) |
| **Data table** | header · row · row-hover · empty (dimmed, iconographic) · own-scroll container |
| **Text field** | default · focus (primary ring) · with JSON validation error |
| **Toggle** | on (primary) · off (neutral), knob elevation 1 |
| **Verdict card** | pass (green) · reject (red, with reason) — check list with PASS/FAIL badges |
| **Proof drawer** | scrim + slide-in panel; copy / download raw proof; failure reason |
| **Dialog** | connect-gate · edit · review (decoded intent) · signing (spinner) · done |
| **Sidebar item** | default · hover · active (primary container + border) |
| **Alert / banner** | info (read-only notice) · warning (request lifecycle) |

---

## 6. Interaction notes

- **Token select:** clicking a sidebar row sets the active token, resets to the
  Facts tab, and closes any open drawer. Active row uses primary-container fill +
  border; kind dot turns primary.
- **Request action gating:** Retract is enabled **only** when `phase ===
  'retractable'` **and** the connected wallet is the original requester. When
  disabled, the button is visibly inert and shows the exact reason beneath it
  ("Only the requester may retract" / "Retract opens after the process window" /
  "Retract window has closed"). Retract itself routes through the review→sign flow.
- **Proof access:** proof chips and Proof buttons open the drawer scoped to that
  fact/request; the workspace verdict pill opens the set-level proof.
- **Write → review → sign:** if no wallet, the dialog first shows a connect step.
  After editing, the **review** step renders the decoded key/value and computed
  intent; only then does "Sign" trigger the (simulated) CIP-30 prompt → signing
  spinner → done confirmation.
- **Empty / loading / error:** tables show dimmed iconographic empty states;
  verification supports a reject verdict (red card + failure reason); disabled
  controls always explain themselves.
- **Copy feedback:** hash chips swap the copy glyph for a green ✓ for 1.2s.

---

## 7. Implementation notes (Halogen port)

- All styling is inline / token-driven — map tokens to a Halogen theme record and
  swap the light/dark table above.
- `HashChip` is the one genuinely reusable widget; everything else is composed from
  the token + chip + table primitives.
- No component depends on a JS runtime library; interactions (tab switch, token
  select, drawer, dialog steps) are plain state transitions.
- Tables own their horizontal scroll (`overflow-x:auto`, `min-width` on `<table>`)
  so the page never overflows.

---

## 8. Status of this deliverable

Implemented interactively in `MPFS Browser.dc.html`:
- Token sidebar (search, Mine filter, select) · token summary + verdict pill
- **Facts** table with decoded JSON + inclusion proof chips
- **Pending requests** table with op/requester/YOU/age/fee/phase/deadline and
  fully gated Retract
- **Verification** tab: verdict card + three checks + snapshot / root / verifier op

Documented above and scaffolded for build-out: proof drawer, write/review/sign
dialogs, first-run view, and 390/768 responsive frames.
