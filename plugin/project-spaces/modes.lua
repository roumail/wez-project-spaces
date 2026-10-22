local wezterm = require 'wezterm'
local ws_labels = require("project-spaces.workspace_labels")
local ws_history = require("project-spaces.workspace_history")
local project_store = require("project-spaces.projects")

local M = {}


function M.build_modes()
  return {
        new_workspace = function(ctx)
          ctx.window:perform_action(
            wezterm.action.PromptInputLine {
              description = "Enter workspace name:",
              action = wezterm.action_callback(function(window, pane, line)
              if not line or line == "" then return end

              if not project_store.exists(line) then
                project_store.add({
                  label = line,
                  path = wezterm.home_dir,
                })
              end
              window:perform_action(
                wezterm.action.SwitchToWorkspace({
                  name = line,
                  spawn = { cwd = wezterm.home_dir },
                }),
                pane
              )
            end),
          },
         ctx.pane)
        end,

        workspace = function(ctx)
          return wezterm.action.SwitchToWorkspace({
            name = ctx.workspace_name,
            -- when user picks an already running workspace, you switch by name
            spawn = ctx.is_active
            and nil or { cwd = ctx.path },
          })
        end,

        alternate_workspace = function(ctx)
          -- The history can outlive workspaces, only switch to one that exists
          ws_history.prune(wezterm.mux.get_workspace_names())
          local target = ws_history.previous(ctx.current_workspace)
          if not target then return nil end
          return wezterm.action.SwitchToWorkspace({
            name = target,
          })
        end,

        tab = function(ctx)
          return wezterm.action.SpawnCommandInNewTab({
            domain="CurrentPaneDomain",
            cwd = ctx.path,
          })
        end,

        split_v  = function(ctx)
          return wezterm.action.SplitHorizontal({
            domain = "CurrentPaneDomain" ,
            cwd = ctx.path,
          })
        end,

        split_h= function(ctx)
          return wezterm.action.SplitVertical({
            domain = "CurrentPaneDomain" ,
            cwd = ctx.path,
          })
        end,
      }
end

return M
