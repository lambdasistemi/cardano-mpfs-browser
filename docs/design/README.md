# MPFS Browser — design source of truth

`SPEC.md` is the authoritative UI/UX spec for the MPFS Browser workbench, produced
from the design brief. The clean-sheet Halogen build implements it screen by screen.

- `SPEC.md` — tokens, layout, screens, components (with states), interactions, Halogen-port notes.
- `MPFS Browser.dc.html` — interactive mockup (dc-runtime; the `<x-dc>` block is the design markup).
- `HashChip.dc.html` — the reusable copy-chip component.

Build target: match this design in Halogen + plain CSS (no React/MUI runtime); re-score with `tools/ux-judge`.
