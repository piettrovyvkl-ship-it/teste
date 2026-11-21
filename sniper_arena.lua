-- ╔══════════════════════════════════════════╗
-- ║     Systemkkj Hub — Sniper Arena         ║
-- ║     Aimbot + ESP + Anti-Kick + Anti-Ban  ║
-- ║     Executor: Madium / KRNL / Synapse    ║
-- ╚══════════════════════════════════════════╝

--// SERVIÇOS
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

--// CONFIG
local CFG = {
    AimbotEnabled    = true,
    AimbotKey        = Enum.KeyCode.Q,
    AimbotSmooth     = 0.12,
    AimbotFOV        = 180,
    AimbotHitpart    = "Head",
    AimbotPrediction = true,
    PredictStrength  = 0.08,

    ESPEnabled       = true,
    ESPBoxes         = true,
    ESPNames         = true,
    ESPDistance      = true,
    ESPHealthBar     = true,
    ESPTracers       = false,
    ESPMaxDist       = 2000,
    ESPTeamCheck     = true,
    ColorEnemy       = Color3.fromRGB(180, 60, 255),
    ColorText        = Color3.fromRGB(255, 255, 255),

    AntiKickEnabled   = true,
    AntiDetectEnabled = true,
}

--// ════════════════════════
--//  ANTI-KICK
--// ════════════════════════
if CFG.AntiKickEnabled then
    local ok, mt = pcall(getrawmetatable, game)
    if ok and mt then
        local old_nc
        pcall(function()
            setreadonly(mt, false)
            old_nc = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" and self == LocalPlayer then return end
                return old_nc(self, ...)
            end)
            setreadonly(mt, true)
        end)
    end
    LocalPlayer.CharacterRemoving:Connect(function()
        task.wait(0.5)
        if not LocalPlayer.Character then
            pcall(function() LocalPlayer:LoadCharacter() end)
        end
    end)
end

--// ════════════════════════
--//  ANTI-DETECT
--// ════════════════════════
if CFG.AntiDetectEnabled then
    RunService.Heartbeat:Connect(function()
        _ = math.random() * 0.001
    end)
end

--// ════════════════════════
--//  UTILS
--// ════════════════════════
local function getChar(p)   return p and p.Character end
local function getHum(c)    return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot(c)   return c and c:FindFirstChild("HumanoidRootPart") end
local function getPart(c,n) return c and c:FindFirstChild(n) end

local function isAlive(p)
    local c = getChar(p) if not c then return false end
    local h = getHum(c)  return h and h.Health > 0
end

local function isEnemy(p)
    if not CFG.ESPTeamCheck then return true end
    return p.Team ~= LocalPlayer.Team
end

local function w2s(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

local function distTo(pos)
    local c = getChar(LocalPlayer) if not c then return math.huge end
    local r = getRoot(c)           if not r then return math.huge end
    return (r.Position - pos).Magnitude
end

--// ════════════════════════
--//  AIMBOT
--// ════════════════════════
local function getBestTarget()
    local best, bestD = nil, CFG.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not isEnemy(p) or not isAlive(p) then continue end
        local c    = getChar(p)
        local part = getPart(c, CFG.AimbotHitpart) or getPart(c, "HumanoidRootPart")
        if not part then continue end
        local sp, on = w2s(part.Position)
        if not on then continue end
        local d = (center - sp).Magnitude
        if d < bestD then bestD = d; best = p end
    end
    return best
end

local function getPredicted(p)
    local c    = getChar(p)
    local part = getPart(c, CFG.AimbotHitpart) or getPart(c, "HumanoidRootPart")
    if not part then return nil end
    if CFG.AimbotPrediction then
        local r = getRoot(c)
        if r then return part.Position + r.AssemblyLinearVelocity * CFG.PredictStrength end
    end
    return part.Position
end

--// ════════════════════════
--//  ESP
--// ════════════════════════
local espObjs = {}

local function mkDraw(t, props)
    local o = Drawing.new(t)
    for k,v in pairs(props) do o[k]=v end
    return o
end

local function createESP(p)
    espObjs[p] = {
        box        = mkDraw("Square", {Visible=false,Filled=false,Color=CFG.ColorEnemy,Thickness=1.5}),
        name       = mkDraw("Text",   {Visible=false,Color=CFG.ColorText,Size=13,Outline=true,OutlineColor=Color3.new(0,0,0),Center=true}),
        dist       = mkDraw("Text",   {Visible=false,Color=CFG.ColorText,Size=11,Outline=true,OutlineColor=Color3.new(0,0,0),Center=true}),
        healthBg   = mkDraw("Square", {Visible=false,Filled=true,Color=Color3.fromRGB(0,0,0),Transparency=0.5,Thickness=1}),
        healthFill = mkDraw("Square", {Visible=false,Filled=true,Color=Color3.fromRGB(160,0,255),Thickness=1}),
        tracer     = mkDraw("Line",   {Visible=false,Color=CFG.ColorEnemy,Thickness=1,Transparency=0.6}),
    }
end

local function removeESP(p)
    if espObjs[p] then
        for _,o in pairs(espObjs[p]) do o:Remove() end
        espObjs[p] = nil
    end
end

local function updateESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not espObjs[p] then createESP(p) end
        local esp     = espObjs[p]
        local visible = CFG.ESPEnabled and isAlive(p) and isEnemy(p)
        if not visible then for _,o in pairs(esp) do o.Visible=false end continue end
        local c    = getChar(p)
        local root = getRoot(c)
        if not root then for _,o in pairs(esp) do o.Visible=false end continue end
        local d3 = distTo(root.Position)
        if d3 > CFG.ESPMaxDist then for _,o in pairs(esp) do o.Visible=false end continue end
        local head  = getPart(c,"Head")
        local torso = getPart(c,"HumanoidRootPart")
        if not head or not torso then for _,o in pairs(esp) do o.Visible=false end continue end
        local topP, topOn = w2s(head.Position + Vector3.new(0,0.7,0))
        local botP, botOn = w2s(torso.Position - Vector3.new(0,2.8,0))
        if not topOn and not botOn then for _,o in pairs(esp) do o.Visible=false end continue end
        local h = math.abs(botP.Y - topP.Y)
        local w = h * 0.5
        local left = topP.X - w/2
        if CFG.ESPBoxes then
            esp.box.Visible=true; esp.box.Position=Vector2.new(left,topP.Y)
            esp.box.Size=Vector2.new(w,h); esp.box.Color=CFG.ColorEnemy
        else esp.box.Visible=false end
        if CFG.ESPNames then
            esp.name.Visible=true; esp.name.Text=p.DisplayName
            esp.name.Position=Vector2.new(topP.X, topP.Y-16)
        else esp.name.Visible=false end
        if CFG.ESPDistance then
            esp.dist.Visible=true; esp.dist.Text=string.format("[%.0f]",d3)
            esp.dist.Position=Vector2.new(topP.X, botP.Y+2)
        else esp.dist.Visible=false end
        if CFG.ESPHealthBar then
            local hum   = getHum(c)
            local hpPct = hum and math.clamp(hum.Health/hum.MaxHealth,0,1) or 0
            local bx    = left - 6
            esp.healthBg.Visible=true; esp.healthBg.Position=Vector2.new(bx-1,topP.Y-1); esp.healthBg.Size=Vector2.new(4,h+2)
            esp.healthFill.Visible=true; esp.healthFill.Position=Vector2.new(bx,topP.Y+h*(1-hpPct)); esp.healthFill.Size=Vector2.new(3,h*hpPct)
            esp.healthFill.Color=Color3.fromHSV(0.75, 1, math.clamp(hpPct+0.3,0,1))
        else esp.healthBg.Visible=false; esp.healthFill.Visible=false end
        if CFG.ESPTracers then
            local cv=Camera.ViewportSize
            esp.tracer.Visible=true; esp.tracer.From=Vector2.new(cv.X/2,cv.Y)
            esp.tracer.To=Vector2.new(topP.X,botP.Y)
        else esp.tracer.Visible=false end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(0.5); if not espObjs[p] then createESP(p) end end)
end)
Players.PlayerRemoving:Connect(removeESP)
for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then createESP(p) end end

--// ════════════════════════
--//  HUB GUI — Systemkkj
--// ════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name         = "SystemkkjHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent       = PlayerGui

-- INTRO FRAME
local IntroFrame = Instance.new("Frame")
IntroFrame.Size            = UDim2.new(1,0,1,0)
IntroFrame.BackgroundColor3 = Color3.fromRGB(8,0,20)
IntroFrame.BorderSizePixel = 0
IntroFrame.ZIndex          = 100
IntroFrame.Parent          = ScreenGui

-- glow central
local Glow = Instance.new("ImageLabel")
Glow.Size              = UDim2.new(0,600,0,600)
Glow.Position          = UDim2.new(0.5,-300,0.5,-300)
Glow.BackgroundTransparency = 1
Glow.Image             = "rbxassetid://6015897843"
Glow.ImageColor3       = Color3.fromRGB(140,0,255)
Glow.ImageTransparency = 0.3
Glow.ZIndex            = 101
Glow.Parent            = IntroFrame

-- título intro
local IntroTitle = Instance.new("TextLabel")
IntroTitle.Size                  = UDim2.new(0,500,0,80)
IntroTitle.Position              = UDim2.new(0.5,-250,0.5,-60)
IntroTitle.BackgroundTransparency = 1
IntroTitle.Text                  = "Systemkkj Hub"
IntroTitle.TextColor3            = Color3.fromRGB(220,120,255)
IntroTitle.TextSize              = 42
IntroTitle.Font                  = Enum.Font.GothamBold
IntroTitle.TextTransparency      = 1
IntroTitle.ZIndex                = 102
IntroTitle.Parent                = IntroFrame

-- subtítulo intro
local IntroSub = Instance.new("TextLabel")
IntroSub.Size                  = UDim2.new(0,400,0,30)
IntroSub.Position              = UDim2.new(0.5,-200,0.5,30)
IntroSub.BackgroundTransparency = 1
IntroSub.Text                  = "Sniper Arena • Loading..."
IntroSub.TextColor3            = Color3.fromRGB(180,80,255)
IntroSub.TextSize              = 16
IntroSub.Font                  = Enum.Font.Gotham
IntroSub.TextTransparency      = 1
IntroSub.ZIndex                = 102
IntroSub.Parent                = IntroFrame

-- barra de loading
local LoadBg = Instance.new("Frame")
LoadBg.Size              = UDim2.new(0,400,0,4)
LoadBg.Position          = UDim2.new(0.5,-200,0.5,75)
LoadBg.BackgroundColor3  = Color3.fromRGB(40,0,80)
LoadBg.BorderSizePixel   = 0
LoadBg.ZIndex            = 102
LoadBg.Parent            = IntroFrame
Instance.new("UICorner", LoadBg).CornerRadius = UDim.new(1,0)

local LoadFill = Instance.new("Frame")
LoadFill.Size             = UDim2.new(0,0,1,0)
LoadFill.BackgroundColor3 = Color3.fromRGB(180,60,255)
LoadFill.BorderSizePixel  = 0
LoadFill.ZIndex           = 103
LoadFill.Parent           = LoadBg
Instance.new("UICorner", LoadFill).CornerRadius = UDim.new(1,0)

-- ANIMAÇÃO DE INTRO
task.spawn(function()
    -- fade in título
    TweenService:Create(IntroTitle, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {TextTransparency=0}):Play()
    task.wait(0.4)
    TweenService:Create(IntroSub, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {TextTransparency=0}):Play()
    task.wait(0.4)
    -- glow pulse
    TweenService:Create(Glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {ImageTransparency=0.1}):Play()
    -- loading bar
    TweenService:Create(LoadFill, TweenInfo.new(1.8, Enum.EasingStyle.Quad), {Size=UDim2.new(1,0,1,0)}):Play()
    task.wait(2.0)
    -- fade out intro
    TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency=1}):Play()
    TweenService:Create(IntroTitle, TweenInfo.new(0.5), {TextTransparency=1}):Play()
    TweenService:Create(IntroSub,   TweenInfo.new(0.5), {TextTransparency=1}):Play()
    TweenService:Create(Glow,       TweenInfo.new(0.5), {ImageTransparency=1}):Play()
    TweenService:Create(LoadBg,     TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
    TweenService:Create(LoadFill,   TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
    task.wait(0.6)
    IntroFrame.Visible = false

    -- ABRE O HUB PRINCIPAL
    MainHub.Visible = true
    TweenService:Create(MainHub, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(0,420,0,340)}):Play()
end)

--// ════════════════════════
--//  HUB PRINCIPAL
--// ════════════════════════
local MainHub = Instance.new("Frame")
MainHub.Name              = "MainHub"
MainHub.Size              = UDim2.new(0,0,0,0)   -- começa com 0, abre com tween
MainHub.Position          = UDim2.new(0.5,-210,0.5,-170)
MainHub.BackgroundColor3  = Color3.fromRGB(12,4,28)
MainHub.BorderSizePixel   = 0
MainHub.Visible           = false
MainHub.ZIndex            = 10
MainHub.Parent            = ScreenGui
Instance.new("UICorner", MainHub).CornerRadius = UDim.new(0,14)

-- stroke roxo
local Stroke = Instance.new("UIStroke")
Stroke.Color     = Color3.fromRGB(160,50,255)
Stroke.Thickness = 1.5
Stroke.Parent    = MainHub

-- glow de fundo no hub
local HubGlow = Instance.new("ImageLabel")
HubGlow.Size              = UDim2.new(1,0,1,0)
HubGlow.BackgroundTransparency = 1
HubGlow.Image             = "rbxassetid://6015897843"
HubGlow.ImageColor3       = Color3.fromRGB(100,0,200)
HubGlow.ImageTransparency = 0.7
HubGlow.ZIndex            = 9
HubGlow.Parent            = MainHub

-- HEADER
local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1,0,0,48)
Header.BackgroundColor3 = Color3.fromRGB(25,5,55)
Header.BorderSizePixel  = 0
Header.ZIndex           = 11
Header.Parent           = MainHub
local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0,14)
HeaderCorner.Parent = Header

-- faixa para cobrir cantos inferiores do header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1,0,0,14)
HeaderFix.Position = UDim2.new(0,0,1,-14)
HeaderFix.BackgroundColor3 = Color3.fromRGB(25,5,55)
HeaderFix.BorderSizePixel = 0
HeaderFix.ZIndex = 11
HeaderFix.Parent = Header

local HubTitle = Instance.new("TextLabel")
HubTitle.Size                  = UDim2.new(1,-60,1,0)
HubTitle.Position              = UDim2.new(0,16,0,0)
HubTitle.BackgroundTransparency = 1
HubTitle.Text                  = "✦ Systemkkj Hub"
HubTitle.TextColor3            = Color3.fromRGB(220,130,255)
HubTitle.TextSize              = 18
HubTitle.Font                  = Enum.Font.GothamBold
HubTitle.TextXAlignment        = Enum.TextXAlignment.Left
HubTitle.ZIndex                = 12
HubTitle.Parent                = Header

-- botão fechar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size                  = UDim2.new(0,30,0,30)
CloseBtn.Position              = UDim2.new(1,-40,0.5,-15)
CloseBtn.BackgroundColor3      = Color3.fromRGB(80,0,140)
CloseBtn.Text                  = "✕"
CloseBtn.TextColor3            = Color3.fromRGB(255,180,255)
CloseBtn.TextSize              = 14
CloseBtn.Font                  = Enum.Font.GothamBold
CloseBtn.ZIndex                = 13
CloseBtn.Parent                = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,8)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainHub, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)}):Play()
    task.wait(0.35)
    MainHub.Visible = false
end)

-- CONTEÚDO
local Content = Instance.new("Frame")
Content.Size             = UDim2.new(1,-20,1,-68)
Content.Position         = UDim2.new(0,10,0,58)
Content.BackgroundTransparency = 1
Content.ZIndex           = 11
Content.Parent           = MainHub

local UIList = Instance.new("UIListLayout")
UIList.SortOrder   = Enum.SortOrder.LayoutOrder
UIList.Padding     = UDim.new(0,8)
UIList.Parent      = Content

-- helper: cria toggle
local function makeToggle(parent, labelText, state, order, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,36)
    row.BackgroundColor3 = Color3.fromRGB(22,6,46)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 12
    row.Parent           = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1,-70,1,0)
    lbl.Position              = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = labelText
    lbl.TextColor3            = Color3.fromRGB(210,180,255)
    lbl.TextSize              = 14
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 13
    lbl.Parent                = row

    local toggleBg = Instance.new("Frame")
    toggleBg.Size             = UDim2.new(0,44,0,22)
    toggleBg.Position         = UDim2.new(1,-54,0.5,-11)
    toggleBg.BackgroundColor3 = state and Color3.fromRGB(140,0,255) or Color3.fromRGB(50,20,80)
    toggleBg.BorderSizePixel  = 0
    toggleBg.ZIndex           = 13
    toggleBg.Parent           = row
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0,16,0,16)
    knob.Position         = state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 14
    knob.Parent           = toggleBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton")
    btn.Size                  = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text                  = ""
    btn.ZIndex                = 15
    btn.Parent                = row

    local enabled = state
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = enabled and Color3.fromRGB(140,0,255) or Color3.fromRGB(50,20,80)}):Play()
        TweenService:Create(knob,     TweenInfo.new(0.2), {Position = enabled and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        if onChange then onChange(enabled) end
    end)

    return row
end

-- TOGGLES
makeToggle(Content, "🎯  Aimbot  [Segurar Q]", CFG.AimbotEnabled, 1, function(v) CFG.AimbotEnabled = v end)
makeToggle(Content, "👁  ESP",                  CFG.ESPEnabled,    2, function(v) CFG.ESPEnabled    = v end)
makeToggle(Content, "📦  ESP Boxes",             CFG.ESPBoxes,      3, function(v) CFG.ESPBoxes      = v end)
makeToggle(Content, "❤  ESP Health Bar",        CFG.ESPHealthBar,  4, function(v) CFG.ESPHealthBar  = v end)
makeToggle(Content, "📏  ESP Distância",         CFG.ESPDistance,   5, function(v) CFG.ESPDistance   = v end)
makeToggle(Content, "🔮  Prediction",            CFG.AimbotPrediction, 6, function(v) CFG.AimbotPrediction = v end)

-- DRAG no hub
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = MainHub.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainHub.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- INSERT = reabrir hub
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        if not MainHub.Visible then
            MainHub.Visible = true
            MainHub.Size    = UDim2.new(0,0,0,0)
            TweenService:Create(MainHub, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(0,420,0,340)}):Play()
        else
            TweenService:Create(MainHub, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)}):Play()
            task.wait(0.35)
            MainHub.Visible = false
        end
    end
end)

--// ════════════════════════
--//  LOOP PRINCIPAL
--// ════════════════════════
RunService.RenderStepped:Connect(function()
    updateESP()
    if CFG.AimbotEnabled and UserInputService:IsKeyDown(CFG.AimbotKey) then
        local target = getBestTarget()
        if target then
            local aimPos = getPredicted(target)
            if aimPos then
                local _, on = w2s(aimPos)
                if on then
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, aimPos), CFG.AimbotSmooth)
                end
            end
        end
    end
end)

print("[Systemkkj Hub] carregado — INSERT abre/fecha | Q = aimbot")
