# MPFS Browser — UX Judge Rubric

Score the MPFS Browser SPA toward the goal: a **usable, workbench-class client for
inspecting MPFS tokens, facts and pending requests and reading their on-chain
verification** (second oracle, facts-set, per-fact inclusion). A vision model scores each
captured screen against these dimensions and emits concrete, ranked gaps.

## Reference bar
There is no single app to clone. The comprehensibility bar is a dense data workbench in
the CQuisitor / cardano-ledger-inspector family: clear hierarchy, type-aware rows,
copyable identifiers, obvious drill-down. The sibling `mpfs-spa` (react-basic + MUI) is a
**look reference only**, never a runtime target. Match that comprehensibility; the
differentiator is making live on-chain verification legible.

## Hard constraints — DO NOT recommend against these (settled decisions)
- **Halogen + a Material *design language* in CSS.** Do NOT recommend React, react-basic,
  MUI, Emotion, Tailwind, or any runtime UI framework — the app is an asset-managing
  signer and keeps a minimal JS trust boundary (spec #32 FR-008). Recommendations must be
  achievable in Halogen + plain CSS with a Material look.
- **Decoding/crypto/verification is WASM-Haskell**, never a JS reimplementation.
- **Identifiers are copyable, middle-truncated `xxxx…yyyy` chips**; data fields
  (fact/request key & value) show their **decoded text**, not raw hex.
- **No page-level horizontal overflow** at any width; long bytes live in bounded chips.
- **Brand is "MPFS Browser"**.

## Differentiator to reward
Legible **on-chain verification**: the second-oracle / facts-set / per-fact-inclusion
verdicts, what was verified (snapshot slot, trusted root, verifier op), and the
request/proof/retract model (who may retract, and when). Reward when a verdict is not just
"Verified" but explains what it means and lets the user inspect the proof.

## Dimensions (score each 1–5; 5 = workbench-class or better)
1. **first_impression** — within the first viewport, is it obvious what this does and how to start?
2. **hierarchy** — is the token/fact/request data the star? Is secondary state demoted until relevant?
3. **data_readability** — decoded values (not hex), copyable truncated hashes, dimmed empty
   states, type-aware rows — not a flat wall of monospace; no overflow.
4. **verification_legibility** — are the verdicts + what-was-verified + proof access clear,
   or just bare "Verified"/"Not verified" labels? (null if N/A on this screen.)
5. **request_clarity** — for a pending request: is the operation, requester, deadlines,
   phase, and **who can retract when** legible? (null if N/A on this screen.)
6. **affordances** — obvious load/refresh actions, copy controls, tabs, disabled reasons,
   labelled form fields, focus states.
7. **polish** — spacing, density, typographic rhythm, Material component consistency,
   styled forms; workbench-dense, not sparse-and-unstyled.

## Output — STRICT JSON only, no prose, no markdown fences
{ "scenario": "<name>", "scores": { "first_impression": n, "hierarchy": n,
  "data_readability": n, "verification_legibility": n or null, "request_clarity": n or null,
  "affordances": n, "polish": n },
  "gaps": [ { "severity": "P1"|"P2"|"P3", "area": "<short>", "what": "<observed>",
  "why": "<impact on usable>", "fix": "<concrete, constraint-respecting>" } ],
  "overall": <integer 0-100> }

Severity: **P1** = blocks "usable" (a first-time user is lost, an action fails, or data is
unreadable). **P2** = major friction. **P3** = polish.
