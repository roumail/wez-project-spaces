-- TODO: just name isn't enough, add the pane working directory too for the
-- workspace
local wezterm = require 'wezterm'
local ws_history = require("project-spaces.workspace_history")
local project_store = require("project-spaces.projects")
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

-- handle case adding a renamed workspace to the choices list
local function add_projects(names)
  for _, name in ipairs(names) do
    if not project_store.exists(name) then
      project_store.add({
        -- TODO: add the exact path of the workspace
        label = name,
        path = wezterm.home_dir,
      })
    end
  end
end

function M.register()
  -- Start empty so workspaces that predate this Lua state are picked up
  local last_seen = {}
  local last_workspace_by_window = {}

  wezterm.on("update-status", function(window, pane)
    local current_workspace = window:active_workspace()
    local window_id = window:window_id()
    if current_workspace == last_workspace_by_window[window_id] then return end
    last_workspace_by_window[window_id] = current_workspace

    local seen = wezterm.mux.get_workspace_names()
    local added, removed, updated_set = M.diff_workspaces(seen, last_seen)
    add_projects(added)
    if #removed > 0 then
      ws_history.prune(seen)
    end
    last_seen = updated_set

    -- Sees every switch, including wezterm moving the window on when
    -- a workspace closes
    ws_history.touch(current_workspace)
  end)
end

return M
