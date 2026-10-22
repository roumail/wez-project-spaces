local wezterm = require 'wezterm'
local M = {}

-- local fifo_cache = require("plugins.fifo-cache.plugin")
local GLOBAL_KEY = "project_spaces_workspace_history"
local history = wezterm.plugin.require("https://github.com/roumail/fifo-cache").new(2)

-- Module state is lost on config reload, wezterm.GLOBAL is not
for _, name in ipairs(wezterm.GLOBAL[GLOBAL_KEY] or {}) do
  history.add_value(name)
end

local function persist()
  wezterm.GLOBAL[GLOBAL_KEY] = history.get_cache()
end

-- Mark a workspace as the most recently used one
function M.touch(name)
  if name == nil then return end
  history.evict_keys({ name })
  history.add_value(name)
  persist()
end

-- Drop workspaces that no longer exist
function M.prune(existing)
  local existing_set = {}
  for _, name in ipairs(existing) do
    existing_set[name] = true
  end

  local stale = {}
  for _, name in ipairs(history.get_cache()) do
    if not existing_set[name] then
      table.insert(stale, name)
    end
  end
  history.evict_keys(stale)
  persist()
end

-- Most recently used workspace other than the current one
function M.previous(current)
  local names = history.get_cache()
  for i = #names, 1, -1 do
    if names[i] ~= current then
      return names[i]
    end
  end
  return nil
end

return M
