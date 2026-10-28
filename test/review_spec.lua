-- Run: nvim -l test/review_spec.lua   (from the repo root; needs LuaSnip)
-- Regression checks for bugs found in review: selections leaking into later
-- files, cut_then_new losing code, and several new files opened together.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(os.getenv("LUASNIP") or vim.fn.expand("~/.local/share/nvimplugged/LuaSnip"))
local skeleton = require("skeleton")
local dir = vim.fn.tempname(); vim.fn.mkdir(dir, "p")
vim.fn.writefile({ "S=${1:$TM_SELECTED_TEXT}" }, dir .. "/skeleton.stories.js")
skeleton.setup({ dirs = { dir } })
local function idle() vim.api.nvim_exec_autocmds("SafeState", {}); vim.wait(300) end
local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end

-- 1. a LuaSnip-cut selection is left alone by a new file with no skeleton,
--    and doesn't land in the next unrelated new file
vim.fn.writefile({ "code" }, dir .. "/src.js")
vim.cmd.edit(dir .. "/src.js")
local src = vim.api.nvim_get_current_buf()
vim.b.LUASNIP_SELECT_RAW, vim.b.LUASNIP_SELECT_DEDENT, vim.b.LUASNIP_TM_SELECT = { "moved()" }, { "moved()" }, { "moved()" }
vim.cmd.edit(dir .. "/notes.txt"); idle()
assert(pcall(vim.api.nvim_buf_get_var, src, "LUASNIP_SELECT_RAW"), "selection still on src")
vim.cmd.edit(dir .. "/Card.stories.js"); idle()
assert(vim.deep_equal(lines(), { "S=" }), "no leak: " .. vim.inspect(lines()))

-- 2. cut_then_new: cancelled prompt deletes nothing; normal-mode call uses the
--    last visual selection; an existing target moves nothing
vim.fn.writefile({ "keep1", "cutme", "keep2" }, dir .. "/a.js")
vim.cmd.edit(dir .. "/a.js")
vim.cmd("normal! 2GV\27") -- leave a last-visual mark on line 2 ('< '>), back in normal
local answer
vim.ui.input = function(_, cb) cb(answer) end
answer = nil; skeleton.cut_then_new(dir)
assert(vim.deep_equal(lines(), { "keep1", "cutme", "keep2" }), "cancel keeps code")
vim.fn.writefile({ "x" }, dir .. "/Exists.stories.js")
answer = "Exists.stories.js"; skeleton.cut_then_new(dir)
assert(vim.deep_equal(lines(), { "keep1", "cutme", "keep2" }), "existing target keeps code")
answer = "Moved.stories.js"; skeleton.cut_then_new(dir); idle()
assert(vim.deep_equal(lines(), { "S=cutme" }), "moved: " .. vim.inspect(lines()))
vim.cmd.buffer(dir .. "/a.js")
assert(vim.deep_equal(lines(), { "keep1", "keep2" }), "cut from source")

-- 3. two new files at once: the one not shown first is filled when entered
vim.cmd.edit(dir .. "/A.stories.js")
vim.cmd.split(dir .. "/B.stories.js"); idle()
assert(vim.deep_equal(lines(), { "S=" }), "B filled")
vim.cmd.wincmd("j"); idle()
assert(vim.fn.bufname():match("A.stories.js") and vim.deep_equal(lines(), { "S=" }), "A filled on enter: " .. vim.inspect(lines()))
print("ok")
