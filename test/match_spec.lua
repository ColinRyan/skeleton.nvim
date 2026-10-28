-- Run: nvim -l test/match_spec.lua   (from the repo root)
-- Checks how skeleton.match parses skeleton names and picks one for a file.
vim.opt.rtp:prepend(vim.fn.getcwd())
local match = require("skeleton.match")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
for _, f in ipairs({ "skeleton.component.tsx", "skeleton.js", "skeleton.stories.js",
  "skeleton.react.functional.js", "skeleton.mobile.eslintrc", "skeleton.web.eslintrc", "yarn-error.log" }) do
  vim.fn.writefile({ "x" }, dir .. "/" .. f)
end
local skels = match.scan({ dir })
local base = function(p) return p and vim.fs.basename(p) end
local names = function(list) local o = vim.tbl_map(function(s) return base(s.path) end, list) table.sort(o) return o end

assert(#skels == 6, "yarn-error.log ignored, got " .. #skels)
for _, s in ipairs(skels) do
  if base(s.path) == "skeleton.react.functional.js" then assert(s.type == "react.functional" and s.ext == "js") end
  if base(s.path) == "skeleton.js" then assert(s.type == nil and s.ext == "js") end
  if base(s.path) == "skeleton.web.eslintrc" then assert(s.type == "web" and s.ext == "eslintrc") end
end

local function auto(name) local r = match.choose(name, skels) return r and base(r.auto) end
assert(auto("Button.tsx") == "skeleton.component.tsx", "single candidate auto")
assert(auto("Button.stories.js") == "skeleton.stories.js", "name match")
assert(auto("A.react.functional.js") == "skeleton.react.functional.js", "dotted type match")

local r = match.choose("Button.test.tsx", skels)
assert(r and r.pick and vim.deep_equal(names(r.pick), { "skeleton.component.tsx" }) and r.default == nil, "unmatched type -> pick")
r = match.choose("foo.js", skels)
assert(r and #r.pick == 3 and base(r.default) == "skeleton.js", "several -> pick with default")
r = match.choose(".eslintrc", skels)
assert(r and #r.pick == 2 and r.default == nil, "dotfile ext")
assert(match.choose("Makefile", skels) == nil, "no ext")
assert(match.choose("x.py", skels) == nil, "no skeleton for ext")
print("ok")
