-- wez_project_source.lua
local wezterm = require("wezterm")
local M = {}

local FILE_NAME = "local_projects.lua"

local function try_load(path)
  local ok, result = pcall(dofile, path)
  if not ok then
    return nil, result
  end
  if type(result) ~= "table" then
    return nil, "file did not return a table"
  end
  return result, nil
end

local function merge_projects(base, loaded)
  local projects = {}

  for _, p in ipairs(base) do
    table.insert(projects, p)
  end

  if type(loaded) == "table" then
    for _, p in ipairs(loaded) do
      table.insert(projects, p)
    end
  end

  return projects
end

function M.load_projects()
  local home_path = wezterm.home_dir .. "/" .. FILE_NAME
  local config_path = wezterm.config_dir .. "/" .. FILE_NAME

  local paths = { home_path, config_path }

  local base_projects = {
    { label = "wez_home", path = wezterm.home_dir },
    { label = "home", path = "~" },
    { label = "config_dir", path = wezterm.config_dir },
  }

  local last_err = nil

  for _, path in ipairs(paths) do
    local loaded_projects, err = try_load(path)
    if loaded_projects then
      return merge_projects(base_projects, loaded_projects)
    end
    last_err = err
  end

  wezterm.log_warn(
    "Could not load " .. FILE_NAME ..
    ". Tried:\n- " .. home_path ..
    "\n- " .. config_path ..
    "\nLast error: " .. tostring(last_err)
  )
  return base_projects
end

return M
