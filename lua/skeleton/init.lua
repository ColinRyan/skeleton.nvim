-- [nfnl] fnl/skeleton/init.fnl
local matcher = require("skeleton.match")
local state = {dirs = {}, pending = nil}
local function escape_lsp(s)
  return (s:gsub("[\\$}]", "\\%0"):gsub("%%", "%%%%"))
end
local function with_name(text, filename)
  local name = escape_lsp((filename:match("^([^.]+)") or filename))
  return (text:gsub("%${NAME}", name):gsub("%$NAME%f[^%w_]", name))
end
local function take_selection(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    local ok, raw = pcall(vim.api.nvim_buf_get_var, buf, "LUASNIP_SELECT_RAW")
    if ok then
      local sel = {LS_SELECT_RAW = raw, LS_SELECT_DEDENT = vim.api.nvim_buf_get_var(buf, "LUASNIP_SELECT_DEDENT"), TM_SELECTED_TEXT = vim.api.nvim_buf_get_var(buf, "LUASNIP_TM_SELECT")}
      for _, v in ipairs({"LUASNIP_SELECT_RAW", "LUASNIP_SELECT_DEDENT", "LUASNIP_TM_SELECT"}) do
        vim.api.nvim_buf_del_var(buf, v)
      end
      return sel
    else
      return nil
    end
  else
    return nil
  end
end
local function expand(buf, path)
  local ls = require("luasnip")
  local text = with_name(table.concat(vim.fn.readfile(path), "\n"), vim.fs.basename(vim.api.nvim_buf_get_name(buf)))
  local snip = ls.parser.parse_snippet("", text, {dedent = false, trim_empty = false})
  local selection = (state.pending or {})
  state.pending = nil
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_win_set_cursor(0, {1, 0})
  return ls.snip_expand(snip, {pos = {0, 0}, expand_params = {env_override = selection}})
end
local function label(s)
  if s.type then
    return (s.type .. "." .. s.ext)
  else
    return (s.ext .. " (default)")
  end
end
local function pick(choices, default, on_choice)
  local items
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, s in ipairs(choices) do
      local val_28_
      if (s.path == default) then
        val_28_ = s
      else
        val_28_ = nil
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    items = tbl_26_
  end
  for _, s in ipairs(choices) do
    if (s.path ~= default) then
      table.insert(items, s)
    else
    end
  end
  table.insert(items, {empty = true})
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values
    local function _7_(s)
      local text
      if s.empty then
        text = "empty file"
      else
        text = label(s)
      end
      return {value = s, display = text, ordinal = text}
    end
    local function _9_(self, entry)
      local function _10_()
        if entry.value.empty then
          return {}
        else
          return vim.fn.readfile(entry.value.path)
        end
      end
      return vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, _10_())
    end
    local function _11_(bufnr)
      local function _12_()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if (entry and not entry.value.empty) then
          return on_choice(entry.value.path)
        else
          return nil
        end
      end
      actions.select_default:replace(_12_)
      return true
    end
    return pickers.new({}, {prompt_title = "Skeleton", finder = finders.new_table({results = items, entry_maker = _7_}), sorter = conf.generic_sorter({}), previewer = previewers.new_buffer_previewer({define_preview = _9_}), attach_mappings = _11_}):find()
  else
    local function _14_(_241)
      if _241.empty then
        return "empty file"
      else
        return label(_241)
      end
    end
    local function _16_(s)
      if (s and not s.empty) then
        return on_choice(s.path)
      else
        return nil
      end
    end
    return vim.ui.select(items, {prompt = "Skeleton", format_item = _14_}, _16_)
  end
end
local function empty_buffer_3f(buf)
  return (vim.api.nvim_buf_is_valid(buf) and (vim.api.nvim_buf_line_count(buf) == 1) and ("" == vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]))
end
local function apply(_3fbuf)
  local buf
  if ((nil == _3fbuf) or (0 == _3fbuf)) then
    buf = vim.api.nvim_get_current_buf()
  else
    buf = _3fbuf
  end
  local filename = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
  local choice = ((filename ~= "") and matcher.choose(filename, matcher.scan(state.dirs)))
  if (choice and empty_buffer_3f(buf)) then
    if choice.auto then
      return expand(buf, choice.auto)
    else
      local function _20_()
        local function _21_(_2410)
          if empty_buffer_3f(buf) then
            return expand(buf, _2410)
          else
            return nil
          end
        end
        return pick(choice.pick, choice.default, _21_)
      end
      return vim.defer_fn(_20_, 150)
    end
  else
    return nil
  end
end
local function new_skeleton(_3fspec)
  local open
  local function _25_(_241)
    if (_241 and (_241 ~= "")) then
      return vim.cmd.edit(vim.fn.fnameescape((vim.fs.normalize(state.dirs[1]) .. "/skeleton." .. _241)))
    else
      return nil
    end
  end
  open = _25_
  if (_3fspec and (_3fspec ~= "")) then
    return open(_3fspec)
  else
    return vim.ui.input({prompt = "New skeleton: skeleton."}, open)
  end
end
local function cut_then_new(_3fdir, _3fprompt, _3fext)
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {type = vim.fn.mode()})
  local dir = (_3fdir or vim.fn.expand("%:p:h"))
  vim.cmd("normal! \"_d")
  state.pending = {LS_SELECT_RAW = lines, LS_SELECT_DEDENT = lines, TM_SELECTED_TEXT = lines}
  local function _28_(name)
    if (name and (vim.trim(name) ~= "")) then
      return vim.cmd.edit(vim.fn.fnameescape((dir .. "/" .. vim.trim(name) .. (_3fext or ""))))
    else
      state.pending = nil
      return nil
    end
  end
  return vim.ui.input({prompt = (_3fprompt or "New file name: "), completion = "file"}, _28_)
end
local function setup(_3fopts)
  state.dirs = ((_3fopts and _3fopts.dirs) or {"~/.config/nvim/skeletons"})
  local function _30_(args)
    if ("" == vim.bo[args.buf].buftype) then
      local from = vim.fn.bufnr("#")
      local function _31_()
        if (args.buf == vim.api.nvim_get_current_buf()) then
          state.pending = (state.pending or take_selection(from))
          return apply(args.buf)
        else
          return nil
        end
      end
      return vim.api.nvim_create_autocmd("SafeState", {once = true, callback = _31_})
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("BufNewFile", {group = vim.api.nvim_create_augroup("skeleton.nvim", {clear = true}), callback = _30_})
  local function _34_()
    return apply(0)
  end
  vim.api.nvim_create_user_command("SkeletonApply", _34_, {desc = "Fill this empty buffer from a skeleton"})
  local function _35_(_241)
    return new_skeleton(_241.args)
  end
  return vim.api.nvim_create_user_command("SkeletonNew", _35_, {nargs = "?", desc = "Create skeleton.<type>.<ext>"})
end
return {setup = setup, apply = apply, new_skeleton = new_skeleton, cut_then_new = cut_then_new, _with_name = with_name, _expand = expand}
