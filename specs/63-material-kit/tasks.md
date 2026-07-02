# Tasks — #63

## Slice 1 — hash/copy core
- [X] T63-S1 Pure `truncateMiddle :: Int -> String -> String` with a RED unit
      test (`xxxx…yyyy`; short strings pass through; keep >= head+tail+ellipsis).
      Clipboard FFI (`writeText`) + a `Copied`/`Idle` state. `HashChip`
      (truncated monospace + title=full + embedded CopyButton) and `CopyButton`
      Halogen components. Material theme tokens + `.hash-chip`/`.copy-button` CSS
      in `dist/index.html`. Gate green. One commit.

## Slice 2 — layout + control primitives
- [X] T63-S2 `Button`, `IconButton`, `Chip`, `StatusChip`, `Paper`,
      `SectionHeader`, `Alert`, `Dialog`, `DataTable` components + CSS. One commit.
