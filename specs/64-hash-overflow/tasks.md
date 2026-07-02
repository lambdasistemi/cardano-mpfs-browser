# Tasks — #64 (epic #72)

## Slice 1 — retrofit hash displays + kill overflows
- [X] T64-S1 Replace every raw long-hex display in `View.purs` (token ids,
      owner, roots, request id, request key/value, fact key/value, tx ids) with
      the `HashChip` component from `MPFS.UI.Material.HashChip`. Ensure the
      Facts request/fact rows and panel containers use `min-width:0` /
      `overflow` so there is **no page-level horizontal overflow** at 360/720/
      1280px. Gate green. One commit. (No app-shell or request-table redesign —
      those are #65/#68.)
