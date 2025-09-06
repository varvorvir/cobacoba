--[[
    Fast Hub - Main (Clean)
    ------------------------------------------------
    Goals:
      • No key (GUI opens immediately)
      • Warm, simple UI
      • 3 buttons: Start CP, Stop, Start To End
      • Pluggable routes (file per map under /routes)
        - Choose route via `_G.ROUTE = "name"` before loading
        - Or at runtime via `_G.FastHub_SetRoute("name")`
    Notes:
      • Route file should `return { start_cp=function()..., stop=function()..., start_to_end=function()... }`
      • Legacy routes that set `_G.StartCP/_G.StopRoute/_G.StartToEnd` are auto-detected
]]

-- ===== Config =====
local BRAND       = "Fast Hub"
local DEFAULT_RT  = _G.ROUTE or "mainmap72"
local ROUTES_BASE = "https://raw.githubusercontent.com/varvorvir/cobacoba/main/routes/"

-- Warm palette
local COLOR = {
    bg     = Color3.fromRGB(24, 18, 16),     -- warm dark
    accent = Color3.fromRGB(255, 159, 67),   -- amber
    text   = Color3.fromRGB(250, 238, 228),
    sub    = Color3.fromRGB(255, 224, 200),
    ok     = Color3.fromRGB(124, 200, 145),
    err    = Color3.fromRGB(230, 90, 90),
    btnG   = Color3.fromRGB(36, 160, 112),
    btnR   = Color3.fromRGB(200, 70, 70),
    btnO   = Color3.fromRGB(220, 140, 60),
}

-- ===== Services & Character =====
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local CoreGui     = game:GetService("CoreGui")

local plr         = Players.LocalPlayer
local char        = plr.Character or plr.CharacterAdded:Wait()
local humanoid    = char:WaitForChild("Humanoid")
local hrp         = char:WaitForChild("HumanoidRootPart")

humanoid.AutoRotate = true
humanoid.Sit = false
hrp.Anchored = false

-- ===== Utilities =====
local function makeCorner(parent, r) local u = Instance.new("UICorner", parent); u.CornerRadius = r or UDim.new(0, 10); return u end
local function makeStroke(parent, th, col) local u = Instance.new("UIStroke", parent); u.Thickness = th or 1; if col then u.Color = col end; return u end

local function makeButton(text, size, pos, bg)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = bg
    b.Text = text
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 16
    b.TextColor3 = Color3.fromRGB(255, 250, 245)
    b.AutoButtonColor = true
    makeCorner(b, UDim.new(0, 10))
    makeStroke(b, 1.2, COLOR.accent)
    return b
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos  = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ===== Walk Animation Feeder =====
local function startWalkFeeder()
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    if not char:FindFirstChild("Animate") then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://507777826"
        local track = animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Movement
        track.Looped = true
        track:Play(0.1, 1, 1)
    end

    local lastPos = hrp.Position
    return RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then return end
        local d = hrp.Position - lastPos
        local flat = Vector3.new(d.X, 0, d.Z)
        if flat.Magnitude > 0.02 then
            humanoid:Move(flat.Unit, true)
        else
            humanoid:Move(Vector3.zero, true)
        end
        lastPos = hrp.Position
    end)
end

-- ===== Route Handling =====
---@class RouteAPI
---@field start_cp fun()
---@field stop fun()
---@field start_to_end fun()

local NOOP_ROUTE = {
    start_cp = function() warn("[FastHub] Route.start_cp not implemented") end,
    stop = function()     warn("[FastHub] Route.stop not implemented") end,
    start_to_end = function() warn("[FastHub] Route.start_to_end not implemented") end,
}

local function detectLegacyRouteFromGlobals()
    local r = {}
    r.start_cp    = rawget(_G, "StartCP")     or rawget(_G, "start_cp") or rawget(_G, "Start_Cp")
    r.stop        = rawget(_G, "StopRoute")   or rawget(_G, "stop")     or rawget(_G, "Stop")
    r.start_to_end= rawget(_G, "StartToEnd")  or rawget(_G, "start_to_end") or rawget(_G, "Start_To_End")
    if r.start_cp or r.stop or r.start_to_end then
        -- Fill blanks with no-ops for safety
        r.start_cp     = r.start_cp     or NOOP_ROUTE.start_cp
        r.stop         = r.stop         or NOOP_ROUTE.stop
        r.start_to_end = r.start_to_end or NOOP_ROUTE.start_to_end
        return r
    end
    return nil
end

local function fetchRouteSource(name)
    local url = ROUTES_BASE .. name .. ".lua?t=" .. tostring(os.time())
    return game:HttpGet(url)
end

local function loadRoute(name)
    local ok, result = pcall(function()
        local src = fetchRouteSource(name)
        local f = loadstring(src)
        return f()
    end)

    if not ok then
        return nil, ("error loading '%s': %s"):format(name, tostring(result))
    end

    -- Prefer module-style table return
    if typeof(result) == "table" then
        return result, nil
    end

    -- Otherwise, try legacy global-style
    local legacy = detectLegacyRouteFromGlobals()
    if legacy then
        return legacy, nil
    end

    return nil, "route returned nothing and legacy globals not found"
end

-- ===== UI Construction =====
local gui = Instance.new("ScreenGui")
gui.Name = "FastHub_UI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(360, 190)
root.Position = UDim2.fromScale(0.07, 0.12)
root.BackgroundColor3 = COLOR.bg
root.BorderSizePixel = 0
root.Parent = gui
makeCorner(root, UDim.new(0, 16))
makeStroke(root, 2, COLOR.accent)

local titleBar = Instance.new("Frame")
titleBar.BackgroundColor3 = COLOR.bg
titleBar.Size = UDim2.new(1, -16, 0, 40)
titleBar.Position = UDim2.fromOffset(8, 8)
titleBar.Parent = root
makeCorner(titleBar, UDim.new(0, 10))
makeStroke(titleBar, 1.5, COLOR.accent)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -80, 0, 22)
title.Position = UDim2.fromOffset(12, 2)
title.Text = BRAND .. " — Ready"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = COLOR.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local routeLabel = Instance.new("TextLabel")
routeLabel.BackgroundTransparency = 1
routeLabel.Size = UDim2.new(1, -80, 0, 16)
routeLabel.Position = UDim2.fromOffset(12, 20)
routeLabel.Text = "Route: " .. DEFAULT_RT
routeLabel.Font = Enum.Font.Gotham
routeLabel.TextSize = 12
routeLabel.TextColor3 = COLOR.sub
routeLabel.TextXAlignment = Enum.TextXAlignment.Left
routeLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 6) -- right padding
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = COLOR.text
closeBtn.BackgroundColor3 = COLOR.accent
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
makeCorner(closeBtn, UDim.new(1, 0))
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

makeDraggable(titleBar, root)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -16, 0, 22)
status.Position = UDim2.fromOffset(8, 56)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextColor3 = COLOR.sub
status.Text = "Loading route..."
status.Parent = root

-- Buttons
local row1 = Instance.new("Frame")
row1.BackgroundTransparency = 1
row1.Size = UDim2.new(1, -16, 0, 50)
row1.Position = UDim2.fromOffset(8, 88)
row1.Parent = root

local startCPBtn = makeButton("Start CP", UDim2.new(0.5, -8, 1, 0), UDim2.fromOffset(0, 0), COLOR.btnG)
startCPBtn.Parent = row1

local stopBtn = makeButton("Stop", UDim2.new(0.5, -8, 1, 0), UDim2.fromScale(0.5, 0), COLOR.btnR)
stopBtn.Parent = row1

local row2 = Instance.new("Frame")
row2.BackgroundTransparency = 1
row2.Size = UDim2.new(1, -16, 0, 50)
row2.Position = UDim2.fromOffset(8, 144)
row2.Parent = root

local startEndBtn = makeButton("Start To End", UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), COLOR.btnO)
startEndBtn.Parent = row2

-- ===== Boot: walk feeder + load route =====
local feederConn = startWalkFeeder()

local currentRoute = NOOP_ROUTE
local function setRoute(name)
    routeLabel.Text = "Route: " .. name
    local route, err = loadRoute(name)
    if route then
        currentRoute = route
        status.Text = "Route loaded ✓"
        status.TextColor3 = COLOR.ok
    else
        currentRoute = NOOP_ROUTE
        status.Text = "Route failed: " .. tostring(err)
        status.TextColor3 = COLOR.err
        warn("[FastHub] "..tostring(err))
    end
end

setRoute(DEFAULT_RT)

-- Button wiring
startCPBtn.MouseButton1Click:Connect(function()
    currentRoute.start_cp()
end)

stopBtn.MouseButton1Click:Connect(function()
    currentRoute.stop()
end)

startEndBtn.MouseButton1Click:Connect(function()
    currentRoute.start_to_end()
end)

-- Public API: change route at runtime
_G.FastHub_SetRoute = function(name)
    setRoute(name)
end

-- Cleanup if GUI destroyed
gui.Destroying:Connect(function()
    if feederConn then feederConn:Disconnect() end
end)
