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

local function build_ctx(window, pane, mode, ws)
  return {
    window = window,
    pane = pane,
    mode = mode,
    current_workspace = window:active_workspace(),
    workspace_history = ws_cache.get(),
    default_workspace = ws_cache.default_workspace(),
    workspace_name = ws and ws.workspace_name,
    path = ws and ws.path,
    is_active = ws and ws.is_active,
    formatted_label = ws and ws.formatted_label,}
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
    for _, name in ipairs(active_workspaces) do
      -- ensure these are stripped names
      active_set[ws_labels.strip_format(name)] = true
    end
    -- default should be there
    local workspaces = {}
    for _, p in ipairs(projects) do
      local is_active = active_set[p.label]
      workspaces[p.label] = {
        workspace_name = p.label,
        path = p.path,
        is_active = is_active,
        formatted_label = ws_labels.format_item(p.label, is_active),
      }
    end
    local choices = {}
    for _, ws in pairs(workspaces) do
      table.insert(choices, {
        id = ws.workspace_name,
        label = ws.formatted_label,
      })
    end

    -- add sort in order of active
    -- input selector
    window:perform_action(
      wezterm.action.InputSelector {
        title = title,
        fuzzy=true,
        --- use wezformat.format on active and display them above
        choices = choices,
        description = 'choose active or new workspace',
        -- switcher layer
        action = wezterm.action_callback(function(window, pane, id, label)
          if not id and not label then return end
          wezterm.log_info("workspaces", wezterm.json_encode(workspaces))
          wezterm.log_info("id", id)
          local ws = workspaces[id]
          if not ws then
            return
          end
          local ctx = build_ctx(window, pane, capability, ws)
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
