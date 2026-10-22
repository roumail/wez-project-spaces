local wezterm = require 'wezterm'
local ws_history = require("project-spaces.workspace_history")
local project_store = require("project-spaces.projects")
local M = {}

function M.register()
  wezterm.on("workspace-removed", function(event)
    ws_history.prune(event.current)
  end)
  -- handle case adding a renamed workspace to the choices list
  wezterm.on("workspace-added", function(event)
    for _, name in ipairs(event.added) do
      if not project_store.exists(name) then
          project_store.add({
            -- TODO: add the exact path once the event metadata is richer
            label = name,
            path = wezterm.home_dir,
            })
      end
    end
  end)
  wezterm.on("workspace-activated", function(name)
    ws_history.touch(name)
  end)
end
return M
