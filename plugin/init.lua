local wezterm = require("wezterm")
local module_id = ...

-- https://wezterm.org/config/plugins.html#managing-a-plugin-with-multiple-lua-modules
for _, plugin in ipairs(wezterm.plugin.list()) do
    if plugin.component == module_id then
        local sep = package.config:sub(1, 1)
        local base = plugin.plugin_dir .. sep .. "plugin" .. sep
        package.path = table.concat({
          package.path,
          base .. "?.lua",
          base .. "?" .. sep .. "init.lua",
        }, ";")
        break
    end
end

return require("project-spaces")
