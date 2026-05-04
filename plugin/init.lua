-- wez_project_spaces.lua
local wezterm = require("wezterm")
local module_id = ...

-- Find the root and add the /lua/ folder to path
for _, plugin in ipairs(wezterm.plugin.list()) do
    if plugin.component == module_id then
        local separator = package.config:sub(1, 1) == '\\' and '\\' or '/'
        package.path = package.path .. ';' .. plugin.plugin_dir .. separator .. 'lua' .. separator .. '?.lua'
        break
    end
end

return require("wez-project-spaces.init")
