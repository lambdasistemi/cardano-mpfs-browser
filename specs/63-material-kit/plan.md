# Plan — #63 Foundation: Halogen Material component kit

Basis: `docs/UI-EVALUATION.md`. Deliver reusable Halogen + CSS Material primitives
with **zero new runtime npm deps**. The design language stabilizes here; later
epic #72 tickets consume these.

## Constraints
- Halogen only (no react-basic/MUI/Emotion — spec #32 FR-008).
- CSS lives in `dist/index.html`'s `<style>` block (tracked); components in
  `src/MPFS/UI/Material/`.
- Theme tokens reused from `purescript-spa-kit/mui` vocabulary as CSS variables:
  neutral bg, primary blue, success/warning, 6px radius, dense spacing.

## Slices (bisect-safe)
- **Slice 1 — hash/copy core (unblocks #64).** A pure middle-truncation helper
  `truncateMiddle :: Int -> String -> String` (`xxxx…yyyy`, RED-tested), a
  clipboard FFI + "copied" state, and `HashChip` + `CopyButton` Halogen
  components. Plus the Material CSS theme tokens + `.hash-chip`/`.copy-button`
  styles. Owned: `src/MPFS/UI/Material/{Text,HashChip,CopyButton,Clipboard}.purs`
  (+ `Clipboard.js`), a `test/Test/**` spec, `dist/index.html` (theme tokens +
  new component CSS only).
- **Slice 2 — layout + control primitives.** `Button`, `IconButton`, `Chip`,
  `StatusChip`, `Paper`, `SectionHeader`, `Alert`, `Dialog`, `DataTable` Halogen
  components + their CSS. Pure/rendering; screenshot-verified via a temporary
  showcase the epic owner drives (no live backend needed).

## Verification
- Slice 1: unit tests for `truncateMiddle` (RED→GREEN); gate green.
- Visual: epic owner (browser access) verifies the components render on the
  preview once a consuming screen exists (#64+); for #63, proof is compile +
  unit tests + the navigator diff review.
