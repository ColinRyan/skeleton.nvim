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
local function expand(buf, path, _3ffrom)
  local ls = require("luasnip")
  local text = with_name(table.concat(vim.fn.readfile(path), "\n"), vim.fs.basename(vim.api.nvim_buf_get_name(buf)))
  local snip = ls.parser.parse_snippet("", text, {dedent = false, trim_empty = false})
  local selection = (state.pending or take_selection(_3ffrom) or {})
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
      local chosen = false
      local function _12_()
        local entry = action_state.get_selected_entry()
        chosen = true
        actions.close(bufnr)
        return on_choice((entry and not entry.value.empty and entry.value.path))
      end
      actions.select_default:replace(_12_)
      local function _13_()
        if not chosen then
          local function _14_()
            return on_choice(nil)
          end
          vim.schedule(_14_)
        else
        end
        return nil
      end
      vim.api.nvim_create_autocmd("BufWipeout", {buffer = bufnr, once = true, callback = _13_})
      return true
    end
    return pickers.new({}, {prompt_title = "Skeleton", finder = finders.new_table({results = items, entry_maker = _7_}), sorter = conf.generic_sorter({}), previewer = previewers.new_buffer_previewer({define_preview = _9_}), attach_mappings = _11_}):find()
  else
    local function _16_(_241)
      if _241.empty then
        return "empty file"
      else
        return label(_241)
      end
    end
    local function _18_(s)
      return on_choice((s and not s.empty and s.path))
    end
    return vim.ui.select(items, {prompt = "Skeleton", format_item = _16_}, _18_)
  end
end
local function empty_buffer_3f(buf)
  return (vim.api.nvim_buf_is_valid(buf) and (vim.api.nvim_buf_line_count(buf) == 1) and ("" == vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]))
end
local function apply(_3fbuf, _3ffrom)
  local buf
  if ((nil == _3fbuf) or (0 == _3fbuf)) then
    buf = vim.api.nvim_get_current_buf()
  else
    buf = _3fbuf
  end
  local filename = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
  local choice = ((filename ~= "") and matcher.choose(filename, matcher.scan(state.dirs)))
  if not (choice and empty_buffer_3f(buf)) then
    state.pending = nil
  elseif choice.auto then
    expand(buf, choice.auto, _3ffrom)
  else
    local function _21_()
      local function _22_(_2410)
        if (_2410 and empty_buffer_3f(buf)) then
          return expand(buf, _2410, _3ffrom)
        else
          state.pending = nil
          return nil
        end
      end
      return pick(choice.pick, choice.default, _22_)
    end
    vim.defer_fn(_21_, 150)
  end
  return nil
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
  local mode = vim.fn.mode()
  local visual_3f = vim.tbl_contains({"v", "V", "\22"}, mode)
  local lines
  if visual_3f then
    lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {type = mode})
  else
    lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), {type = vim.fn.visualmode()})
  end
  local dir = (_3fdir or vim.fn.expand("%:p:h"))
  if visual_3f then
    vim.cmd("exe \"normal! \\<Esc>\"")
  else
  end
  local function _30_(name)
    local name0 = (name and vim.trim(name))
    local path = (name0 and (name0 ~= "") and (dir .. "/" .. name0 .. (_3fext or "")))
    if not path then
      return nil
    elseif (1 == vim.fn.filereadable(path)) then
      return vim.notify(("skeleton.nvim: " .. path .. " exists; nothing moved"), vim.log.levels.WARN)
    else
      vim.cmd("normal! gvd")
      state.pending = {LS_SELECT_RAW = lines, LS_SELECT_DEDENT = lines, TM_SELECTED_TEXT = lines}
      return vim.cmd.edit(vim.fn.fnameescape(path))
    end
  end
  return vim.ui.input({prompt = (_3fprompt or "New file name: "), completion = "file"}, _30_)
end
local function apply_when_idle(buf, from)
  local function _32_()
    if vim.api.nvim_buf_is_valid(buf) then
      if (buf == vim.api.nvim_get_current_buf()) then
        apply(buf, from)
      else
        local function _33_()
          apply_when_idle(buf, from)
          return nil
        end
        vim.api.nvim_create_autocmd("BufEnter", {buffer = buf, once = true, callback = _33_})
      end
    else
    end
    return nil
  end
  return vim.api.nvim_create_autocmd("SafeState", {once = true, callback = _32_})
end
local function setup(_3fopts)
  state.dirs = ((_3fopts and _3fopts.dirs) or {"~/.config/nvim/skeletons"})
  local function _36_(args)
    if ("" == vim.bo[args.buf].buftype) then
      apply_when_idle(args.buf, vim.fn.bufnr("#"))
    else
    end
    return nil
  end
  vim.api.nvim_create_autocmd("BufNewFile", {group = vim.api.nvim_create_augroup("skeleton.nvim", {clear = true}), callback = _36_})
  local function _38_()
    return apply(0)
  end
  vim.api.nvim_create_user_command("SkeletonApply", _38_, {desc = "Fill this empty buffer from a skeleton"})
  local function _39_(_241)
    return new_skeleton(_241.args)
  end
  return vim.api.nvim_create_user_command("SkeletonNew", _39_, {nargs = "?", desc = "Create skeleton.<type>.<ext>"})
end
return {setup = setup, apply = apply, new_skeleton = new_skeleton, cut_then_new = cut_then_new, _with_name = with_name, _expand = expand}
