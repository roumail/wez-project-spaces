-- wez_new_workspace.lua
local wezterm = require 'wezterm'
local M = {}

function M.diff_workspaces(current_list, previous_set)
  local added = {}
  local removed = {}
  local new_set = {}

  -- build new set + detect additions
  for _, name in ipairs(current_list) do
    new_set[name] = true
    if not previous_set[name] then
      table.insert(added, name)
    end
  end

  -- detect removals
  for name, _ in pairs(previous_set) do
    if not new_set[name] then
      table.insert(removed, name)
    end
  end

  return added, removed, new_set
end


function M.setup()
  local last_seen = (function()
    local initial = {}
    for _, name in ipairs(wezterm.mux.get_workspace_names()) do
      initial[name] = true
    end
    return initial
  end)()

  local last_workspace = nil
  wezterm.on("update-status", function(window, pane)
    local current_workspace = window:active_workspace()

    if current_workspace ~= last_workspace then
      last_workspace = current_workspace

      local seen = wezterm.mux.get_workspace_names()
      local added, removed, updated_set = M.diff_workspaces(seen, last_seen)

      if #added > 0 or #removed > 0 then
        wezterm.emit("workspace-changed", {
          added = added,
          removed = removed,
          current = seen,
        })
      end

      if #added > 0 then
        wezterm.emit("workspace-added", {
          added = added,
          current = seen,
        })
      end
      if #removed > 0 then
        wezterm.emit("workspace-removed", {
          removed = removed,
          current = seen,
        })
      end
      last_seen = updated_set
    end
  end)
end

return M
