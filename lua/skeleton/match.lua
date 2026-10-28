-- [nfnl] fnl/skeleton/match.fnl
local function parse_skeleton(path)
  local rest = vim.fs.basename(path):match("^skeleton%.(.+)$")
  if rest then
    local type_2a, ext = rest:match("^(.+)%.([^.]+)$")
    if ext then
      return {path = path, type = type_2a, ext = ext}
    else
      return {path = path, ext = rest}
    end
  else
    return nil
  end
end
local function scan(dirs)
  local out = {}
  for _, dir in ipairs(dirs) do
    for name, kind in vim.fs.dir(vim.fs.normalize(dir)) do
      if ((kind == "file") or (kind == "link")) then
        local s = parse_skeleton((vim.fs.normalize(dir) .. "/" .. name))
        if s then
          table.insert(out, s)
        else
        end
      else
      end
    end
  end
  local function _5_(_241, _242)
    return (_241.path < _242.path)
  end
  table.sort(out, _5_)
  return out
end
local function file_parts(filename)
  local name = (filename:match("^%.(.+)$") or filename)
  local ext = name:match("%.([^.]+)$")
  if filename:match("^%.[^.]+$") then
    return {ext = name, typed = false}
  elseif ext then
    return {ext = ext, typed = (nil ~= name:sub(1, (#name - #ext - 1)):find(".", 1, true))}
  else
    return nil
  end
end
local function choose(filename, skeletons)
  local parts = file_parts(filename)
  local candidates
  if parts then
    local tbl_26_ = {}
    local i_27_ = 0
    for _, s in ipairs(skeletons) do
      local val_28_
      if (s.ext == parts.ext) then
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
    candidates = tbl_26_
  else
    candidates = {}
  end
  if (#candidates > 0) then
    local named = nil
    for _, s in ipairs(candidates) do
      if (s.type and vim.endswith(filename, ("." .. s.type .. "." .. s.ext)) and (not named or (#s.type > #named.type))) then
        named = s
      else
      end
    end
    if named then
      return {auto = named.path}
    elseif (not parts.typed and (1 == #candidates)) then
      return {auto = candidates[1].path}
    else
      local _11_
      do
        local d = nil
        for _, s in ipairs(candidates) do
          local or_12_ = d
          if not or_12_ then
            if (nil == s.type) then
              or_12_ = s.path
            else
              or_12_ = nil
            end
          end
          d = or_12_
        end
        _11_ = d
      end
      return {pick = candidates, default = _11_}
    end
  else
    return nil
  end
end
return {scan = scan, choose = choose, ["parse-skeleton"] = parse_skeleton}
