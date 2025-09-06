--[[
    Fast Hub - Loader (Clean)
    -----------------------------------------
    - No key / gate
    - Fetches `main.lua` from GitHub and executes it
]]

local MAIN_URL = "https://raw.githubusercontent.com/varvorvir/cobacoba/main/main.lua"

local ok, err = pcall(function()
    local src = game:HttpGet(MAIN_URL .. "?t=" .. tostring(os.time()))
    local run = loadstring(src)
    return run()
end)

if not ok then
    warn("[FastHub/Loader] Failed to load main.lua:", err)
end
