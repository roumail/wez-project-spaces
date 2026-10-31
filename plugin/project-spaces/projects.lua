local wezterm = require("wezterm")
local FILE_NAME = "local_projects.lua"

local projects = {
  { label = "default", path = wezterm.home_dir },
  { label = "home", path = "~" },
  { label = "config_dir", path = wezterm.config_dir },
}
local paths = {
  wezterm.home_dir .. "/" .. FILE_NAME,
  wezterm.config_dir .. "/" .. FILE_NAME,
}

local last_err
for _, path in ipairs(paths) do
  local ok, loaded = pcall(dofile, path)
  if ok and type(loaded) == "table" then
    for _, p in ipairs(loaded) do
      table.insert(projects, p)
    end
    return projects
  end
  last_err = ok and "file did not return a table" or loaded
end

wezterm.log_warn(
  "Could not load " .. FILE_NAME ..
  ". Tried:\n- " .. table.concat(paths, "\n- ") ..
  "\nLast error: " .. tostring(last_err)
)
return projects
