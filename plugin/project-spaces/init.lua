local wezterm = require("wezterm")
local projects = require("project-spaces.projects")
local registered = false
local M = {}

-- Module state is lost on config reload, wezterm.GLOBAL is not.
-- Least recently used first
local HISTORY_KEY = "project_spaces_workspace_history"
local HISTORY_CAPACITY = 2

local function keep_history(predicate)
  local kept = {}
  local stored = wezterm.GLOBAL[HISTORY_KEY] or {}
  -- wezterm.GLOBAL hands an empty list back as an object, which ipairs
  -- can't index, but # still reads 0
  for i = 1, #stored do
    local name = stored[i]
    if predicate(name) then
      table.insert(kept, name)
    end
  end
  return kept
end

local function existing_workspaces()
  local existing = {}
  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    existing[name] = true
  end
  return existing
end

local function add_project(name)
  for _, p in ipairs(projects) do
    if p.label == name then return end
  end
  table.insert(projects, { label = name, path = wezterm.home_dir })
end

local handlers = {
  new_workspace = function()
    return wezterm.action.PromptInputLine {
      description = "Enter workspace name:",
      action = wezterm.action_callback(function(window, pane, line)
        if not line or line == "" then return end
        add_project(line)
        window:perform_action(
          wezterm.action.SwitchToWorkspace({
            name = line,
            spawn = { cwd = wezterm.home_dir },
          }),
          pane
        )
      end),
    }
  end,

  workspace = function(_, ws)
    return wezterm.action.SwitchToWorkspace({
      name = ws.name,
      -- when user picks an already running workspace, you switch by name
      spawn = not ws.is_active and { cwd = ws.path } or nil,
    })
  end,

  alternate_workspace = function(window)
    -- The history can outlive workspaces, only switch to one that exists
    local existing = existing_workspaces()
    local history = keep_history(function(name) return existing[name] end)
    wezterm.GLOBAL[HISTORY_KEY] = history
    for i = #history, 1, -1 do
      if history[i] ~= window:active_workspace() then
        return wezterm.action.SwitchToWorkspace({ name = history[i] })
      end
    end
  end,

  tab = function(_, ws)
    return wezterm.action.SpawnCommandInNewTab({
      domain = "CurrentPaneDomain",
      cwd = ws.path,
    })
  end,

  split_v = function(_, ws)
    return wezterm.action.SplitHorizontal({
      domain = "CurrentPaneDomain",
      cwd = ws.path,
    })
  end,

  split_h = function(_, ws)
    return wezterm.action.SplitVertical({
      domain = "CurrentPaneDomain",
      cwd = ws.path,
    })
  end,
}

local function run(window, pane, mode, ws)
  local action = handlers[mode](window, ws)
  if action then
    window:perform_action(action, pane)
  end
end

function M.apply_to_config(config, opts)
  opts = opts or {}

  -- Handlers live in the Lua state of this config evaluation, gui-startup
  -- fires only once so registering there loses them on reload
  if not registered then
    local last_workspace_by_window = {}
    wezterm.on("update-status", function(window)
      local current_workspace = window:active_workspace()
      local window_id = window:window_id()
      if current_workspace == last_workspace_by_window[window_id] then return end
      last_workspace_by_window[window_id] = current_workspace

      local existing = existing_workspaces()
      -- Workspaces made outside the selector, by a rename for one, are
      -- offered in it too.
      -- TODO: record the workspace's cwd instead of the home directory.
      -- TODO: after renaming the active workspace, say "work" to "notes",
      -- the selector should list both "notes" and "work"; it doesn't.
      for name in pairs(existing) do
        add_project(name)
      end

      -- Sees every switch, including wezterm moving the window on when
      -- a workspace closes
      local kept = keep_history(function(name)
        return existing[name] and name ~= current_workspace
      end)
      table.insert(kept, current_workspace)
      while #kept > HISTORY_CAPACITY do
        table.remove(kept, 1)
      end
      wezterm.GLOBAL[HISTORY_KEY] = kept
    end)
    registered = true
  end

  local default_bindings = {
    workspace = { key = "w", mods = "LEADER" },
    alternate_workspace = { key = string.upper(config.leader.key), mods = "LEADER|SHIFT" },
    tab = { key = "t", mods = "LEADER" },
    split_v = { key = "V", mods = "LEADER|SHIFT" },
    split_h = { key = "H", mods = "LEADER|SHIFT" },
  }
  local user_bindings = opts.bindings or {}

  for capability, default in pairs(default_bindings) do
    local binding = user_bindings[capability]
    if binding == nil then binding = default end
    if binding then
      table.insert(config.keys, {
        key = binding.key,
        mods = binding.mods,
        action = wezterm.action_callback(function(window, pane)
          if capability == "alternate_workspace" then
            return run(window, pane, capability)
          end

          local active = existing_workspaces()
          local tab_counts = {}
          for _, mux_window in ipairs(wezterm.mux.all_windows()) do
            local workspace = mux_window:get_workspace()
            tab_counts[workspace] = (tab_counts[workspace] or 0) + #mux_window:tabs()
          end

          local workspaces = {}
          for _, p in ipairs(projects) do
            workspaces[p.label] = {
              name = p.label,
              path = p.path == "~" and wezterm.home_dir
                or (p.path:gsub("^~/", wezterm.home_dir .. "/", 1)),
              is_active = active[p.label] or false,
            }
          end

          local choices = {}
          for name, ws in pairs(workspaces) do
            local tab_count = tab_counts[name] or 0
            table.insert(choices, {
              id = name,
              label = ws.is_active
                and wezterm.format({
                  { Attribute = { Intensity = "Bold" } },
                  { Foreground = { AnsiColor = "Green" } },
                  { Text = " ● " .. name .. " (" .. tab_count .. (tab_count == 1 and " tab)" or " tabs)") },
                })
                or wezterm.format({
                  { Foreground = { AnsiColor = "Silver" } },
                  "ResetAttributes",
                  { Text = "   " .. name .. " " },
                }),
            })
          end

          table.sort(choices, function(a, b)
            local wa = workspaces[a.id]
            local wb = workspaces[b.id]
            if wa.is_active ~= wb.is_active then
              return wa.is_active
            end
            return wa.name < wb.name
          end)
          table.insert(choices, 1, {
            id = "___NEW___",
            label = wezterm.format({
              { Foreground = { AnsiColor = "Green" } },
              { Text = " + Create New Workspace..." },
            }),
          })

          window:perform_action(
            wezterm.action.InputSelector {
              title = opts.title or ("Select Project (" .. capability .. ")"),
              fuzzy = true,
              choices = choices,
              description = "choose active or new workspace",
              action = wezterm.action_callback(function(window, pane, id)
                if id == "___NEW___" then
                  return run(window, pane, "new_workspace")
                end
                if workspaces[id] then
                  run(window, pane, capability, workspaces[id])
                end
              end),
            },
            pane
          )
        end),
      })
    end
  end
end

return M
