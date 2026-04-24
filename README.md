# fifo-cache

A tiny FIFO cache utility for WezTerm configs.
It tracks unique values in insertion order up to a fixed capacity.
Once the cache reaches capacity, it becomes ready, and adding a new unique value evicts the oldest one.

## Installation

Add to your `wezterm.lua` configuration file:

```lua
local wezterm = require("wezterm")
local config = wezterm.config_builder()

local fifo_cache = wezterm.plugin.require("https://github.com/roumail/fifo-cache")

local cacheA = fifo_gate.new(2)
-- using it in your config

cacheA.add_value("a")
cacheA.add_value("b")

cacheB.add_value("x")

if cacheA.is_ready() then
    print("A ready", table.concat(cacheA.get_cache(), ","))
end

if cacheB.is_ready() then
    print("B ready", table.concat(cacheB.get_cache(), ","))
end

return config
```
