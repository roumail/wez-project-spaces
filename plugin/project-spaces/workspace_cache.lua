local wezterm = require 'wezterm'
local M = {}

local cache_settled = true
-- local fifo_cache = require("plugins.fifo-cache.plugin")
local workspace_cache = wezterm.plugin.require("https://github.com/roumail/fifo-cache").new(2)
local DEFAULT_WORKSPACE = "default"

function M.is_settled()
  return cache_settled
end

function M.get()
  return workspace_cache.get_cache()
end

function M.add(name)
  return workspace_cache.add_value(name)
end

function M.is_full()
  return workspace_cache.is_ready()
end

function M.reorder()
  return workspace_cache.reverse()
end

function M.default_workspace()
  return DEFAULT_WORKSPACE
end

-- Drop cached workspaces that no longer exist
function M.prune(existing)
  local existing_set = {}
  for _, name in ipairs(existing) do
    existing_set[name] = true
  end

  local stale = {}
  for _, name in ipairs(workspace_cache.get_cache()) do
    if not existing_set[name] then
      table.insert(stale, name)
    end
  end
  workspace_cache.evict_keys(stale)
end

function M.handle_workspace_removed(event)
  cache_settled = false
  -- Normalize cache first to prevent cache being out of sync
  -- with reality
  M.prune(event.current)
  workspace_cache.evict_keys(event.removed)
  cache_settled = true
end

return M
