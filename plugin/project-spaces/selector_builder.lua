local wezterm = require 'wezterm'
local project_store = require("project-spaces.projects")
local ws_labels = require("project-spaces.workspace_labels")

local M = {}

local function expand_home(path)
  if path == "~" then
    return wezterm.home_dir
  end

  return path:gsub("^~/", wezterm.home_dir .. "/", 1)
end

function M.build()
    local active_workspaces = wezterm.mux.get_workspace_names()
    local active_set = {}
    for _, name in ipairs(active_workspaces) do
      active_set[name] = true
    end
    local num_tabs_by_workspace = {}

    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      local workspace = mux_window:get_workspace()
      local num_tabs = #mux_window:tabs()

      num_tabs_by_workspace[workspace] = (num_tabs_by_workspace[workspace] or 0) + num_tabs
    end

    -- default should be there
    local workspaces = {}
    local projects = project_store.all()
    for _, p in ipairs(projects) do
      local is_active = active_set[p.label]
      local tab_count = num_tabs_by_workspace[p.label] or 0
      workspaces[p.label] = {
        workspace_name = p.label,
        path = expand_home(p.path),
        is_active = is_active,
        formatted_label = ws_labels.format_item(p.label, is_active, tab_count),
      }
    end
    local choices = {}
    for _, ws in pairs(workspaces) do
      table.insert(choices, {
        id = ws.workspace_name,
        label = ws.formatted_label,
      })
    end

    -- input selector
    table.sort(choices, function(a, b)
      local wa = workspaces[a.id]
      local wb = workspaces[b.id]

      if wa.is_active ~= wb.is_active then
        return wa.is_active
      end

      return wa.workspace_name < wb.workspace_name
    end)

    table.insert(choices, 1, {
      id = "___NEW___",
      label = wezterm.format({
          { Foreground = { AnsiColor = 'Green' } },
          { Text = " + Create New Workspace..." },
        })
    }
    )
    return {
      workspaces = workspaces,
      choices = choices,
    }
end

return M
