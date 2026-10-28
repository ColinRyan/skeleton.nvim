-- Run: nvim -l test/apply_spec.lua   (from the repo root; needs LuaSnip at
-- ~/.local/share/nvimplugged/LuaSnip or $LUASNIP)
-- Checks that a new file gets its skeleton expanded, with $NAME and the
-- stored selection filled, and that a non-empty buffer is left alone.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(os.getenv("LUASNIP") or vim.fn.expand("~/.local/share/nvimplugged/LuaSnip"))
local skeleton = require("skeleton")

assert(skeleton._with_name("import $NAME from './${NAME}'", "Button.stories.js") == "import Button from './Button'")
assert(skeleton._with_name("$NAMES $NAME_X", "A.js") == "$NAMES $NAME_X", "only the exact variable")
assert(skeleton._with_name("$NAME", "a$b.js") == "a\\$b", "value escaped for snippet syntax")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
vim.fn.writefile({ "import $NAME from './$NAME'", "const x = ${1:value}", "${2:$TM_SELECTED_TEXT}" },
  dir .. "/skeleton.stories.js")
skeleton.setup({ dirs = { dir } })

-- an existing source file with a stored selection (as LuaSnip's cut keys
-- leave it)
vim.fn.writefile({ "code" }, dir .. "/src.js")
vim.cmd.edit(dir .. "/src.js")
vim.b.LUASNIP_SELECT_RAW = { "moved()" }
vim.b.LUASNIP_SELECT_DEDENT = { "moved()" }
vim.b.LUASNIP_TM_SELECT = { "moved()" }

vim.cmd.edit(dir .. "/Button.stories.js") -- doesn't exist: BufNewFile
vim.api.nvim_exec_autocmds("SafeState", {}) -- headless: no idle loop
vim.wait(1000, function() return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" end)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(vim.deep_equal(lines, { "import Button from './Button'", "const x = value", "moved()" }), vim.inspect(lines))

-- a second new file in the same session gets its skeleton too (the
-- BufNewFile hook must survive its first use)
vim.cmd.edit(dir .. "/Card.stories.js")
vim.api.nvim_exec_autocmds("SafeState", {})
vim.wait(1000, function() return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" end)
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "import Card from './Card'", "second new file")

-- an existing, non-empty file is never touched
vim.fn.writefile({ "keep" }, dir .. "/Old.stories.js")
vim.cmd.edit(dir .. "/Old.stories.js")
skeleton.apply()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "keep" }))
print("ok")
