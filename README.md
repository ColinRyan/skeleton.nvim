# skeleton.nvim

Fills new files from skeleton templates, expanded by LuaSnip so you can
`<C-j>` through the tab stops.

Skeletons are files named `skeleton.<type>.<ext>` or `skeleton.<ext>` in the
directories you give `setup`:

- `Button.stories.js` uses `skeleton.stories.js` (the name says the type)
- `Button.tsx` uses the only `.tsx` skeleton, if there is exactly one
- anything else opens a picker (the plain `skeleton.<ext>` preselected,
  plus "empty file")

Templates use LSP snippet syntax (`$1`, `${1:default}`, `$0`,
`$TM_SELECTED_TEXT`) plus `$NAME`, the file name up to its first dot.

```lua
require("skeleton").setup({ dirs = { "~/.config/nvim/skeletons" } })
```

`:SkeletonNew [type.ext]` makes a skeleton, `:SkeletonApply` fills the
current empty buffer. Source is Fennel in `fnl/`, compiled by nfnl into
`lua/`. Tests: `nvim -l test/match_spec.lua`.
