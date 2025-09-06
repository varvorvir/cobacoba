-- routes/example.lua (Clean)
-- Template route module for Fast Hub.
local M = {}

local running = false

function M.start_cp()
    running = true
    print("[route/example] start_cp")
    -- TODO: implement
end

function M.stop()
    running = false
    print("[route/example] stop")
    -- TODO: implement cleanup
end

function M.start_to_end()
    running = true
    print("[route/example] start_to_end")
    -- TODO: implement
end

return M
