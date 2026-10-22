local wezterm = require 'wezterm'
local M = {}

-- Module state is lost on config reload, wezterm.GLOBAL is not
local GLOBAL_KEY = "project_spaces_workspace_history"
local CAPACITY = 2

local function keep(predicate)
  local kept = {}
  for _, name in ipairs(wezterm.GLOBAL[GLOBAL_KEY] or {}) do
    if predicate(name) then
      table.insert(kept, name)
    end
  end
  return kept
end

-- Plain copy, least recently used first
local function names()
  return keep(function() return true end)
end

-- Mark a workspace as the most recently used one
function M.touch(name)
  if name == nil then return end
  local kept = keep(function(n) return n ~= name end)
  table.insert(kept, name)
  while #kept > CAPACITY do
    table.remove(kept, 1)
  end
  wezterm.GLOBAL[GLOBAL_KEY] = kept
end

-- Drop workspaces that no longer exist
function M.prune(existing)
  local existing_set = {}
  for _, name in ipairs(existing) do
    existing_set[name] = true
  end
  wezterm.GLOBAL[GLOBAL_KEY] = keep(function(n) return existing_set[n] end)
end

-- Most recently used workspace other than the current one
function M.previous(current)
  local history = names()
  for i = #history, 1, -1 do
    if history[i] ~= current then
      return history[i]
    end
  end
  return nil
end

return M
