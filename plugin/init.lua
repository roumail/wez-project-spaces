-- fifo_gate.lua
local M = {}

function M.new(capacity)
    local seen = {}
    local order = {}
    local ready = false

    local function evict_oldest()
        local oldest = table.remove(order, 1)
        if oldest then
            seen[oldest] = nil
        end
    end

    local function add_value(v)
        if not seen[v] then
            if #order >= capacity then
                evict_oldest()
            end

            seen[v] = true
            table.insert(order, v)
        end

        if #order >= capacity then
            ready = true
        end

        return ready
    end

    local function is_ready()
        return ready
    end

    local function get_cache()
        local copy = {}
        for i, v in ipairs(order) do
            copy[i] = v
        end
        return copy
    end

    return {
        add_value = add_value,
        is_ready = is_ready,
        get_cache = get_cache
    }
end

return M
