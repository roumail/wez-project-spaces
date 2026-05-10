local wezterm = require 'wezterm'
local bindings = require("project-spaces.bindings")
local ws_labels = require("project-spaces.workspace_labels")
local mode_registry = require("project-spaces.modes")
local projects = require("project-spaces.projects").load_projects()
local events = require("project-spaces.events")
local ws_cache = require("project-spaces.workspace_cache")
local M = {}

-- local wez_new_ws = require("plugins.wez-new-workspace.plugin")
-- https://github.com/wezterm/wezterm/issues/2933
-- wsl expects this to be done sooner
wezterm.on('gui-startup', function()
  wezterm.plugin.require("https://github.com/roumail/wez-new-workspace").setup()
  events.register()
end)

local function resolve_action(modes, ctx)
  local handler = modes[ctx.mode]
   if not handler then return nil end
  return handler(ctx)
end

local function build_ctx(window, pane, mode, extra)
  return {
    window = window,
    pane = pane,
    mode = mode,
    current_workspace = window:active_workspace(),
    cwd = pane:get_current_working_dir(),
    workspace_history = ws_cache.get(),
    default_workspace = ws_cache.default_workspace(),
    workspace_name = extra and extra.workspace_name,
    target_path = extra and extra.target_path,
  }
end

local function project_selector(capability, opts)
  local opts = opts or {}
  local title = opts.title or ("Select Project (" .. capability .. ")")
  local handlers = mode_registry.build_modes()
  -- source-selector layer
  return wezterm.action_callback(function(window, pane)
    if capability == "alternate_workspace" then
      local ctx = build_ctx(window, pane, capability)
      local action = resolve_action(handlers, ctx)

      if action then
        window:perform_action(action, pane)
	  end
      return
    end
    local active_workspaces = wezterm.mux.get_workspace_names()
    local active_set = {}
    local choices = {}
    local choice_meta = {}

    -- reason to store active workspaces by name and
    -- others by path is because the formatted names
    -- create issues
    for _, name in ipairs(active_workspaces) do
      active_set[name] = true
      choice_meta[name] = {
        workspace_name = name,
        is_active_workspace = true,
      }
      table.insert(choices, {
        label = ws_labels.format_item(name, true),
        id = name,
      })
    end

    for _, p in ipairs(projects) do
      if type(p) == "table" and p.label and p.path then
        if not active_set[p.label] then
          choice_meta[p.path] = {
            workspace_name = p.label,
            is_active_workspace=false,
          }
          table.insert(choices, {
            label = ws_labels.format_item(p.label, false),
            id = p.path,
          })
        end
      end
    end

    -- input selector
    window:perform_action(
      wezterm.action.InputSelector {
        title = title,
        fuzzy=true,
        --- use wezformat.format on active and display them above
        choices = choices,
        description = 'choose active or new workspace',
        -- switcher layer
        action = wezterm.action_callback(function(window, pane, target_path, label)
          if not target_path and not label then return end
          -- in case it's an active workspace it's going to be
          -- keyed by name, else by path
          local meta = choice_meta[label] or choice_meta[target_path] or {}
          local ctx = build_ctx(window, pane, capability, {
              workspace_name = meta.workspace_name,
              is_active_workspace= meta.is_active_workspace,
              target_path = target_path,
            })
          local next_action = resolve_action(handlers, ctx)
          if next_action then
            window:perform_action(next_action, pane)
          end
        end)
      },
      pane
    )
  end)
end

function M.apply_to_config(config, opts)
  bindings.apply(config, opts, function(mode)
    return project_selector(mode, opts)
  end)
end

return M
