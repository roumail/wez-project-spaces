# wez-workspace-alt

A WezTerm plugin that provides:

1. Alternate-workspace toggling (`LEADER|SHIFT+B`)
2. Instrumented workspace switching for selectors/actions

It tracks the last two unique workspaces using [fifo-cache](https://github.com/roumail/fifo-cache) and switches between them. Once two workspaces have been seen, pressing the toggle key switches back and forth between them.

## Installation

Add to your `wezterm.lua` configuration file:

```lua
local wezterm = require("wezterm")
local config = wezterm.config_builder()

local wez_ws_alt = wezterm.plugin.require("https://github.com/roumail/wez-workspace-alt")

-- Registers LEADER+SHIFT+B to toggle between the two most recent workspaces
wez_ws_alt.apply_to_config(config)

return config
```

## Exports

### `apply_to_config(config)`

Registers a keybinding on `config.keys`:

- key: `B`
- mods: `LEADER|SHIFT`
- action: switch to alternate workspace (if history is ready)

Behavior:

- Tracks current workspace on invocation
- If fewer than 2 unique workspaces have been seen, does nothing
- Otherwise switches to “the other” workspace in the 2-item cache

### `switch_workspace(callback)`-> wezterm_action`

Returns an instrumented `action_callback` that tracks workspace transitions before delegating to your callback.

The callback receives:
- `do_switch(name, spawn)` — call this to perform the tracked workspace switch
- `path` — the value passed as `id` in the selector choice
- `label` — the display label of the selected choice

Returns a `wezterm.action_callback(...)` suitable for `InputSelector.action` and similar event-driven selectors.

This is the integration point for instrumented switching.

## Callback Contract

You pass a function with this exact shape:

```lua
function callback(do_switch, path, label)
  -- your logic
end
```

Parameters:

- `do_switch(name, spawn?)`
- `path` (selector `id` value)
- `label` (selector label value)

### `do_switch` contract

`do_switch` is injected by this plugin and performs tracked workspace switching.

Signature:

```lua
do_switch(name, spawn)
```

## Example Usage

```lua
local wez_ws_alt = wezterm.plugin.require("https://github.com/roumail/wez-workspace-alt")

wez_ws_alt.apply_to_config(config)

local action = wez_ws_alt.switch_workspace(function(do_switch, path, label)
  if not path then
    return
  end
  do_switch(label, { cwd = path })
end)
```

Then use `action` as the `InputSelector.action`.

## Invariants / Expectations

- Workspace history capacity is fixed at 2.
- History tracks unique names (as defined by fifo-cache behavior).
- Alternate switch chooses the non-current workspace from the 2-item history.
- No-op if target is nil or equals current workspace.

## Error/Edge Behavior

- If history is not ready (fewer than 2), alternate switch does nothing.
- If selector is cancelled (`path == nil`), caller callback should no-op.
- Empty/nil workspace names are ignored by tracker.

