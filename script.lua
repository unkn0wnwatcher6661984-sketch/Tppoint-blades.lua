local P = game:GetService("Players")
local W = game:GetService("Workspace")
local U = game:GetService("UserInputService")
local R = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local pl = P.LocalPlayer
if not pl then return end

local pg = pl:WaitForChild("PlayerGui")
local m = pl:GetMouse()
local c = pl.Character or pl.CharacterAdded:Wait()
local cam = W.CurrentCamera

local TP_INSTANCE_ID = HttpService:GenerateGUID(false)
local TP_INSTANCE_PASSWORD = string.format("%08d", math.random(0, 99999999))

local bk = {
    curPage = 1,
    ok = false,
    pl_rad = false,
    sf_act = false,
    cnt = 0,
    safe_hp = 0.30,
    safe_pos = nil,
    mapPoints = {},
    playerPoints = {}
}

local connections = {}
local guiClosed = false
local buildGui

local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(connections, connection)
    return connection
end

local function disconnectOwnConnections()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
end

local W_T, CD, SF_CD, PL_CD = 2, 4, 7, 5
local t1, t2, t3, t_sf, t_pl = 0, 0, 0, 0, 0
local HRP = "HumanoidRootPart"

local specActive, specIndex = false, 0
local specCamBtn, specExitBtn, specConnection
local specYaw, specPitch, specDistance = 0, -0.65, 18
local rotating, lastPointer, inConfigMode = false, nil, false

local sg, MF, cfgBtn, minBtn, closeBtn
local scroll1, scroll2, scroll3
local layout1, layout2, layout3
local createBtn, radarBtn, refreshBtn, safeBtn
local navLeft, navLabel, navRight
local zone
local configFrame, cfgLabel, hpInput, hpSaveBtn, cfgBackBtn
local xInput, yInput, zInput
local safe_data
local frameOpen = true

local THEME = {
    background = Color3.fromRGB(18, 20, 29),
    panel = Color3.fromRGB(25, 28, 40),
    header = Color3.fromRGB(15, 17, 25),
    text = Color3.fromRGB(245, 247, 255),
    muted = Color3.fromRGB(155, 165, 185),
    border = Color3.fromRGB(57, 64, 84),
    red = Color3.fromRGB(235, 75, 85),
    blue = Color3.fromRGB(65, 145, 255),
    green = Color3.fromRGB(45, 195, 130),
    button = Color3.fromRGB(39, 44, 61),
    input = Color3.fromRGB(31, 35, 49)
}

local function roundify(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    return corner
end

local function outline(object, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.15
    stroke.Parent = object
    return stroke
end

local function styleButton(button, color)
    button.AutoButtonColor = true
    button.BorderSizePixel = 0
    button.BackgroundColor3 = color or THEME.button
    button.TextColor3 = THEME.text
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 11
    roundify(button, 7)
end

local function snd(id, speed)
    if guiClosed then return end

    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = 1
    s.PlaybackSpeed = speed or 1
    s.Parent = W.CurrentCamera or W

    connect(s.Ended, function()
        s:Destroy()
    end)

    s:Play()
end

local function tp(pos, isPl, tPl)
    if guiClosed then return end

    c = pl.Character
    if not c or not c:FindFirstChild(HRP) then return end

    local dest = pos

    if isPl and tPl and tPl.Character then
        local targetRoot = tPl.Character:FindFirstChild(HRP)
        if targetRoot then
            dest = targetRoot.Position - targetRoot.CFrame.LookVector * 3
            c:PivotTo(CFrame.new(dest, targetRoot.Position))
            snd(9120705982, 1.5)
            return
        end
    end

    if typeof(dest) ~= "Vector3" then return end

    snd(9120705982, 1.5)
    c:PivotTo(CFrame.new(dest + Vector3.new(0, 3, 0)))
end

local function endSpectate()
    specActive, rotating, lastPointer = false, false, nil

    if specConnection then
        specConnection:Disconnect()
        specConnection = nil
    end

    cam = W.CurrentCamera

    if cam then
        cam.CameraType = Enum.CameraType.Custom

        local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            cam.CameraSubject = hum
        end
    end

    if specCamBtn then
        specCamBtn:Destroy()
        specCamBtn = nil
    end

    if specExitBtn then
        specExitBtn:Destroy()
        specExitBtn = nil
    end
end

local function updateSpecCamera()
    if not specActive or guiClosed then return end

    local item = bk.mapPoints[specIndex]

    if not item or not item.Ancor or not item.Ancor.Parent then
        endSpectate()
        return
    end

    cam = W.CurrentCamera
    if not cam then return end

    cam.CameraType = Enum.CameraType.Scriptable

    local targetPos = item.Ancor.Position - Vector3.new(0, 10, 0)
    local cp = math.clamp(specPitch, -1.35, 1.1)

    local direction = Vector3.new(
        math.cos(cp) * math.sin(specYaw),
        math.sin(cp),
        math.cos(cp) * math.cos(specYaw)
    )

    cam.CFrame = CFrame.lookAt(
        targetPos - direction * specDistance,
        targetPos
    )
end

local function jumpSpectate(offset)
    if #bk.mapPoints == 0 then return end

    specIndex += offset

    if specIndex > #bk.mapPoints then
        specIndex = 1
    elseif specIndex < 1 then
        specIndex = #bk.mapPoints
    end

    updateSpecCamera()
end

local function startSpectate(_, idx)
    if guiClosed or not sg then return end

    endSpectate()

    if #bk.mapPoints == 0 then return end

    specActive = true
    specIndex = idx or 1
    specYaw, specPitch = 0, -0.35

    specCamBtn = Instance.new("TextButton")
    specCamBtn.Name = "TP_SpecCam_" .. TP_INSTANCE_ID
    specCamBtn:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    specCamBtn.Size = UDim2.new(0, 140, 0, 40)
    specCamBtn.Position = UDim2.new(0.5, -75, 0.82, 0)
    specCamBtn.Text = "Ir ao ponto"
    specCamBtn.Parent = sg
    styleButton(specCamBtn, THEME.green)

    specExitBtn = Instance.new("TextButton")
    specExitBtn.Name = "TP_SpecExit_" .. TP_INSTANCE_ID
    specExitBtn:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    specExitBtn.Size = UDim2.new(0, 40, 0, 40)
    specExitBtn.Position = UDim2.new(0.5, 70, 0.82, 0)
    specExitBtn.Text = "X"
    specExitBtn.Parent = sg
    styleButton(specExitBtn, THEME.red)

    connect(specCamBtn.MouseButton1Click, function()
        if guiClosed then return end

        local item = bk.mapPoints[specIndex]
        if item then
            tp(item.Pos, false, nil)
        end

        endSpectate()
    end)

    connect(specExitBtn.MouseButton1Click, endSpectate)

    specConnection = R.RenderStepped:Connect(updateSpecCamera)
    table.insert(connections, specConnection)

    updateSpecCamera()
end

connect(U.InputBegan, function(input, processed)
    if processed or not specActive or guiClosed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        rotating, lastPointer = true, input.Position
    end
end)

connect(U.InputChanged, function(input)
    if not specActive or not rotating or not lastPointer or guiClosed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - lastPointer
        lastPointer = input.Position

        specYaw -= delta.X * 0.008
        specPitch = math.clamp(
            specPitch + delta.Y * 0.008,
            -1.35, 1.1
        )
    end
end)

connect(U.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        rotating, lastPointer = false, nil
    end
end)

local function makeLabel3D(pos, txt, isPl)
    local part = Instance.new("Part")
    part.Name = "TP_TextAncor_" .. TP_INSTANCE_ID
    part:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    part:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.Position = pos + Vector3.new(0, 10, 0)
    part.Parent = W

    local gui = Instance.new("BillboardGui")
    gui.Name = "TP_Billboard_" .. TP_INSTANCE_ID
    gui.Size = UDim2.new(0, 110, 0, 36)
    gui.AlwaysOnTop = true
    gui.Adornee = part
    gui.Parent = part

    local btn = Instance.new("TextButton")
    btn.Name = "TP_LabelButton_" .. TP_INSTANCE_ID
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = THEME.header
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = txt
    btn.TextColor3 = isPl and THEME.blue or THEME.red
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = gui

    roundify(btn, 7)
    return part, btn
end

-- Detailed knife models with surface-aware orientation and a physical drop/attach system.
local function knifeSurfaceCFrame(position, normal, roll)
    -- The knife's blade extends along local -Y. Align local +Y with the
    -- surface's outward normal, so the blade points into floors, walls,
    -- ceilings, and sloped surfaces alike.
    if typeof(normal) ~= "Vector3" or normal.Magnitude < 0.001 then
        normal = Vector3.yAxis
    else
        normal = normal.Unit
    end

    local reference = math.abs(normal:Dot(Vector3.yAxis)) > 0.97
        and Vector3.xAxis or Vector3.yAxis
    local right = reference:Cross(normal).Unit
    local back = right:Cross(normal).Unit
    local basis = CFrame.fromMatrix(position, right, normal, back)
    return basis * CFrame.Angles(0, 0, roll or 0)
end

local function createDetailedKnife(position, accent, name, scale)
    scale = scale or 1
    local model = Instance.new("Model")
    model.Name = name or "TP_DetailedKnife"
    model:SetAttribute("KnifeScale", scale)

    -- The invisible root is the true pivot for the whole knife. This prevents
    -- the blade (the first visible part) from becoming the pivot and shifting
    -- the knife away from the surface when PivotTo is called.
    local root = Instance.new("Part")
    root.Name = "KnifeRoot"
    root.Size = Vector3.new(0.12, 0.12, 0.12) * scale
    root.Transparency = 1
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.Massless = false
    root.CFrame = CFrame.new(position)
    root.Parent = model
    model.PrimaryPart = root

    local silver = Color3.fromRGB(215, 222, 235)
    local brightSilver = Color3.fromRGB(248, 250, 255)
    local darkMetal = Color3.fromRGB(28, 31, 40)
    local accentDark = accent:Lerp(Color3.new(0, 0, 0), 0.38)
    local accentLight = accent:Lerp(Color3.new(1, 1, 1), 0.35)

    local function part(partName, size, offset, color, material)
        local obj = Instance.new("Part")
        obj.Name = partName
        obj.Size = size * scale
        obj.Color = color
        obj.Material = material or Enum.Material.Metal
        obj.CanCollide = false
        obj.CanTouch = true
        obj.CanQuery = false
        obj.Massless = true
        obj.Anchored = true
        obj.TopSurface = Enum.SurfaceType.Smooth
        obj.BottomSurface = Enum.SurfaceType.Smooth
        obj.CFrame = CFrame.new(position) * CFrame.new(offset * scale)
        obj.Parent = model

        local weld = Instance.new("WeldConstraint")
        weld.Name = "KnifePartWeld"
        weld.Part0 = root
        weld.Part1 = obj
        weld.Parent = root
        return obj
    end

    -- The blade tip is local -Y; the knife's local +Y is aimed away from the
    -- surface, so the blade points into the surface when the knife is placed.
    part("Blade", Vector3.new(0.20, 1.28, 0.085), Vector3.new(0, -0.64, 0), silver)
    part("BladeTip", Vector3.new(0.13, 0.24, 0.07), Vector3.new(0, -1.40, 0), brightSilver)
    part("BladeSpine", Vector3.new(0.035, 1.14, 0.022), Vector3.new(0, -0.63, -0.050), brightSilver)
    part("DarkFuller", Vector3.new(0.035, 0.84, 0.018), Vector3.new(0, -0.61, 0.050), darkMetal)
    part("Guard", Vector3.new(0.72, 0.13, 0.17), Vector3.new(0, 0.12, 0), accent, Enum.Material.Metal)
    part("GuardLeft", Vector3.new(0.14, 0.17, 0.19), Vector3.new(-0.30, 0.12, 0), accentDark)
    part("GuardRight", Vector3.new(0.14, 0.17, 0.19), Vector3.new(0.30, 0.12, 0), accentDark)
    part("Grip", Vector3.new(0.23, 0.68, 0.19), Vector3.new(0, 0.52, 0), darkMetal, Enum.Material.Slate)
    part("GripCore", Vector3.new(0.13, 0.55, 0.205), Vector3.new(0, 0.52, 0), accentDark, Enum.Material.Metal)
    part("GripAccentFront", Vector3.new(0.18, 0.12, 0.025), Vector3.new(0, 0.55, -0.108), accentLight, Enum.Material.Neon)
    part("GripAccentBack", Vector3.new(0.18, 0.12, 0.025), Vector3.new(0, 0.55, 0.108), accent, Enum.Material.Neon)
    for i = 1, 4 do
        part("GripRing" .. i, Vector3.new(0.255, 0.035, 0.215), Vector3.new(0, 0.27 + i * 0.15, 0), i % 2 == 0 and accentLight or accent, Enum.Material.Metal)
    end
    part("Pommel", Vector3.new(0.31, 0.16, 0.24), Vector3.new(0, 0.91, 0), accent)
    part("PommelCore", Vector3.new(0.15, 0.09, 0.255), Vector3.new(0, 0.91, -0.14), brightSilver)

    -- Extra blue inlays make the player-radar knife more ornate.
    if accent.B > 0.6 and accent.R < 0.3 then
        part("BlueBladeInlayA", Vector3.new(0.022, 0.60, 0.016), Vector3.new(-0.050, -0.63, -0.054), accentLight, Enum.Material.Neon)
        part("BlueBladeInlayB", Vector3.new(0.022, 0.60, 0.016), Vector3.new(0.050, -0.63, -0.054), accent, Enum.Material.Neon)
        part("BlueGuardGem", Vector3.new(0.13, 0.13, 0.13), Vector3.new(0, 0.12, -0.115), accentLight, Enum.Material.Neon)
        part("BluePommelGem", Vector3.new(0.12, 0.12, 0.12), Vector3.new(0, 0.91, -0.14), accent, Enum.Material.Neon)
        part("BlueGuardStripeL", Vector3.new(0.10, 0.045, 0.19), Vector3.new(-0.23, 0.12, -0.01), accentLight, Enum.Material.Neon)
        part("BlueGuardStripeR", Vector3.new(0.10, 0.045, 0.19), Vector3.new(0.23, 0.12, -0.01), accentLight, Enum.Material.Neon)
    end

    model.Parent = W
    model:PivotTo(CFrame.new(position))
    return model
end

local function setKnifeState(model, anchored, collide)
    if not model then return end
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = anchored
            obj.CanCollide = collide == true and (obj.Name == "Blade" or obj.Name == "BladeTip")
            obj.CanTouch = obj.Name ~= "KnifeRoot"
            obj.Massless = obj.Name ~= "KnifeRoot"
        end
    end
end

local function removeKnifeWeld(model)
    if not model then return end
    local weld = model:FindFirstChild("CharacterKnifeWeld", true)
    if weld then weld:Destroy() end
end

local dropKnifeOnSurface
local surfaceWatchers = setmetatable({}, {__mode = "k"})

local function clearSurfaceAttachment(model)
    if not model then return end
    local watcher = surfaceWatchers[model]
    if watcher then
        watcher:Disconnect()
        surfaceWatchers[model] = nil
    end
    local weld = model:FindFirstChild("KnifeSurfaceWeld", true)
    if weld then weld:Destroy() end
end

local function stickKnifeToSurface(model, hitPosition, normal, surfacePart, playStickSound)
    if not model or not model.Parent or not model.PrimaryPart then return end

    -- Remove a previous surface attachment/watch before attaching again.
    clearSurfaceAttachment(model)

    if typeof(normal) ~= "Vector3" or normal.Magnitude < 0.01 then
        normal = Vector3.yAxis
    else
        normal = normal.Unit
    end

    local scale = model:GetAttribute("KnifeScale") or 1
    -- Local -Y is the blade direction. The knife's tip is placed just outside
    -- the hit plane while its handle remains on the outside of the surface.
    local pivotPosition = hitPosition + normal * (1.52 * scale + 0.015)

    model:PivotTo(knifeSurfaceCFrame(pivotPosition, normal))
    model:SetAttribute("SurfacePoint", hitPosition)
    model:SetAttribute("SurfaceNormal", normal)
    model:SetAttribute("Dropped", true)

    -- Sound played when a falling knife sticks to a new surface. Initial TPPoint
    -- placement uses the existing spawn sound once, without doubling it here.
    if playStickSound ~= false then
        snd(137951817204948, 1)
    end

    if surfacePart and surfacePart:IsA("BasePart") and surfacePart:IsDescendantOf(W) then
        -- Keep the knife physically attached if its support is simply unanchored
        -- or moved. If that support is deleted, the watcher releases the knife.
        setKnifeState(model, false, false)
        local root = model.PrimaryPart
        root.Massless = false
        root.CanCollide = false
        root.CanTouch = false

        local surfaceWeld = Instance.new("WeldConstraint")
        surfaceWeld.Name = "KnifeSurfaceWeld"
        surfaceWeld.Part0 = surfacePart
        surfaceWeld.Part1 = root
        surfaceWeld.Parent = root

        local watcher
        watcher = R.Heartbeat:Connect(function()
            if not model.Parent or not root.Parent then
                if watcher then watcher:Disconnect() end
                surfaceWatchers[model] = nil
                return
            end
            if not surfacePart.Parent or not surfacePart:IsDescendantOf(W)
                or not surfaceWeld.Parent or surfaceWeld.Part0 == nil then
                if watcher then watcher:Disconnect() end
                surfaceWatchers[model] = nil
                if surfaceWeld.Parent then surfaceWeld:Destroy() end
                model:SetAttribute("Falling", false)
                dropKnifeOnSurface(model, root.AssemblyLinearVelocity)
            end
        end)
        surfaceWatchers[model] = watcher
    else
        -- Terrain has no BasePart to weld to, so keep the knife fixed in place.
        setKnifeState(model, true, false)
    end
end

local function attachLabelToKnife(labelPart, model)
    if not labelPart or not labelPart.Parent or not model or not model.Parent or not model.PrimaryPart then
        return false
    end

    local oldWeld = labelPart:FindFirstChild("TP_LabelKnifeWeld")
    if oldWeld then oldWeld:Destroy() end

    -- Preserve the label's current world position, then weld it to the knife root.
    -- It therefore follows the knife physically, including falling into the void.
    labelPart.Anchored = false
    labelPart.CanCollide = false
    labelPart.CanTouch = false
    labelPart.CanQuery = false
    labelPart.Massless = true

    local weld = Instance.new("WeldConstraint")
    weld.Name = "TP_LabelKnifeWeld"
    weld.Part0 = model.PrimaryPart
    weld.Part1 = labelPart
    weld.Parent = labelPart
    return true
end

local function attachKnifeToHead(model, character, height)
    local head = character and character:FindFirstChild("Head")
    if not model or not model.Parent or not head or not model.PrimaryPart then return false end
    removeKnifeWeld(model)
    clearSurfaceAttachment(model)
    model:SetAttribute("Dropped", false)
    model:SetAttribute("Falling", false)
    setKnifeState(model, false, false)
    model:PivotTo(head.CFrame * CFrame.new(0, height or 1.15, 0))
    local weld = Instance.new("WeldConstraint")
    weld.Name = "CharacterKnifeWeld"
    weld.Part0, weld.Part1, weld.Parent = head, model.PrimaryPart, model.PrimaryPart
    return true
end

dropKnifeOnSurface = function(model, launchVelocity)
    if not model or not model.Parent or model:GetAttribute("Falling") then return end

    removeKnifeWeld(model)
    clearSurfaceAttachment(model)
    model:SetAttribute("Dropped", true)
    model:SetAttribute("Falling", true)

    local root = model.PrimaryPart
    if not root then
        model:SetAttribute("Falling", false)
        return
    end

    -- Capture any existing throw velocity before enabling physics. If no
    -- velocity was supplied, use the current assembly velocity; only use a
    -- gentle downward fall as a fallback (e.g. for SafePoint).
    local velocity = launchVelocity
    if typeof(velocity) ~= "Vector3" then
        velocity = root.AssemblyLinearVelocity
    end
    if velocity.Magnitude < 0.1 then
        velocity = Vector3.new(0, -2, 0)
    end

    setKnifeState(model, false, true)
    root.Massless = false
    root.CanCollide = false
    root.CanTouch = false
    root.AssemblyLinearVelocity = velocity
    root.AssemblyAngularVelocity = Vector3.zero

    local landed = false
    local lastPosition = root.Position
    local lastTipPosition = model:FindFirstChild("BladeTip") and model.BladeTip.Position or root.Position
    local monitorConnection
    local touchConnections = {}

    local function disconnectTouches()
        for _, connection in ipairs(touchConnections) do
            connection:Disconnect()
        end
        table.clear(touchConnections)
        if monitorConnection then
            monitorConnection:Disconnect()
            monitorConnection = nil
        end
    end

    local function tryStick(result)
        if landed or not result or not result.Instance then return end
        if result.Instance:IsDescendantOf(model) then return end
        if result.Instance:IsA("BasePart") and not result.Instance.CanCollide then return end

        landed = true
        disconnectTouches()
        stickKnifeToSurface(model, result.Position, result.Normal, result.Instance)
        model:SetAttribute("Falling", false)
    end

    local function onTouched(hit)
        if landed or not model.Parent or not hit or not hit.Parent then return end
        if hit:IsDescendantOf(model) then return end
        if hit:IsA("BasePart") and not hit.CanCollide then return end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {model, pl.Character}
        params.IgnoreWater = true

        local direction = root.AssemblyLinearVelocity
        if direction.Magnitude < 0.1 then
            direction = -root.CFrame.UpVector
        else
            direction = direction.Unit
        end

        -- Probe both the knife's center and its tip. This detects the actual
        -- surface normal when a blade first hits a vertical wall or floor.
        local result = W:Raycast(root.Position - direction * 1.8, direction * 3.6, params)
        if not result then
            local tip = model:FindFirstChild("BladeTip")
            if tip then
                result = W:Raycast(tip.Position - direction * 1.8, direction * 3.6, params)
            end
        end
        if not result then
            local towardHit = hit.Position - root.Position
            if towardHit.Magnitude > 0.05 then
                result = W:Raycast(root.Position - towardHit.Unit * 1.8, towardHit.Unit * 3.6, params)
            end
        end
        if result and result.Instance == hit then
            tryStick(result)
        end
    end

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "KnifeRoot" then
            table.insert(touchConnections, obj.Touched:Connect(onTouched))
        end
    end

    -- A swept raycast catches thin walls and floors even if Touched misses them.
    monitorConnection = R.Heartbeat:Connect(function()
        if landed or not model.Parent or not root.Parent then
            disconnectTouches()
            return
        end

        local currentPosition = root.Position
        local delta = currentPosition - lastPosition
        local tip = model:FindFirstChild("BladeTip")
        local currentTipPosition = tip and tip.Position or currentPosition
        local tipDelta = currentTipPosition - lastTipPosition

        if delta.Magnitude > 0.001 or tipDelta.Magnitude > 0.001 then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {model, pl.Character}
            params.IgnoreWater = true

            -- Sweep the root and blade tip so fast impacts with thin geometry
            -- are detected and the knife can orient to the real impact normal.
            local result
            if delta.Magnitude > 0.001 then
                result = W:Raycast(lastPosition, delta, params)
            end
            if not result and tipDelta.Magnitude > 0.001 then
                result = W:Raycast(lastTipPosition, tipDelta, params)
            end
            if result then
                tryStick(result)
            end
        end

        lastPosition = currentPosition
        lastTipPosition = currentTipPosition
    end)
end

local function removeKnife(item)
    if item and item.Knife then
        item.Knife:Destroy()
        item.Knife = nil
    end
end

local function surfaceNormalFromMouse()
    local target = m.Target
    if not target then return Vector3.yAxis end
    local hitPos = m.Hit.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {pl.Character}
    local origin = cam and cam.CFrame.Position or hitPos + Vector3.new(0, 8, 0)
    local direction = hitPos - origin
    local result = direction.Magnitude > 0 and W:Raycast(origin, direction, params) or nil
    if result and result.Instance == target then return result.Normal end
    return Vector3.yAxis
end

local function rebuildLists()
    if guiClosed or not scroll1 or not scroll2 or not scroll3 then
        return
    end

    local function clearRows(scroll)
        for _, child in ipairs(scroll:GetChildren()) do
            if not child:IsA("UIListLayout")
                and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
    end

    clearRows(scroll1)
    clearRows(scroll2)
    clearRows(scroll3)

    for i, item in ipairs(bk.mapPoints) do
        local bMap = Instance.new("TextButton")
        bMap.Name = "TPPoint_" .. TP_INSTANCE_ID .. "_" .. tostring(item.Idx)
        bMap.Size = UDim2.new(1, -6, 0, 34)
        bMap.Text = "   ◆   tppoint " .. tostring(item.Idx)
        bMap.TextXAlignment = Enum.TextXAlignment.Left
        bMap.Parent = scroll1
        styleButton(bMap, Color3.fromRGB(45, 38, 49))

        connect(bMap.MouseButton1Click, function()
            if not guiClosed then
                tp(item.Pos, false, nil)
            end
        end)

        local bSpec = Instance.new("TextButton")
        bSpec.Name = "SpecPoint_" .. TP_INSTANCE_ID .. "_" .. tostring(item.Idx)
        bSpec.Size = UDim2.new(1, -6, 0, 34)
        bSpec.Text = "   ◉   Spec Point " .. tostring(item.Idx)
        bSpec.TextXAlignment = Enum.TextXAlignment.Left
        bSpec.Parent = scroll3
        styleButton(bSpec, Color3.fromRGB(34, 45, 62))

        connect(bSpec.MouseButton1Click, function()
            if not guiClosed then
                startSpectate(item.Pos, i)
            end
        end)
    end

    for _, item in ipairs(bk.playerPoints) do
        local bPl = Instance.new("TextButton")
        bPl.Name = "Player_" .. TP_INSTANCE_ID .. "_" .. tostring(item.PlName)
        bPl.Size = UDim2.new(1, -6, 0, 34)
        bPl.Text = "   ●   " .. tostring(item.PlName)
        bPl.TextXAlignment = Enum.TextXAlignment.Left
        bPl.Parent = scroll2
        styleButton(bPl, Color3.fromRGB(30, 45, 65))
        bPl.TextColor3 = Color3.fromRGB(130, 195, 255)

        connect(bPl.MouseButton1Click, function()
            if guiClosed then return end

            local target = P:FindFirstChild(item.PlName)

            if target and target.Character
                and target.Character:FindFirstChild(HRP) then
                tp(target.Character[HRP].Position, true, target)
            elseif item.Pos then
                tp(item.Pos, false, nil)
            end
        end)
    end
end

local function addListButton(pos, isPl, targetPlayer, index, surfaceNormal, surfacePart)
    if guiClosed or not pos then return end

    local name = isPl and targetPlayer.Name or ("tppoint " .. tostring(index))
    local anchor, labelButton = makeLabel3D(pos, name, isPl)
    local knife
    if isPl then
        knife = createDetailedKnife(pos + Vector3.new(0, 2.2, 0), Color3.fromRGB(20, 125, 255), "RadarKnife_" .. targetPlayer.UserId, 0.72)
        attachKnifeToHead(knife, targetPlayer.Character, 1.05)
    else
        local normal = surfaceNormal or Vector3.yAxis
        knife = createDetailedKnife(pos, Color3.fromRGB(235, 45, 55), "TPPointKnife_" .. tostring(index), 1)
        -- Attach to the actual clicked BasePart instead of anchoring beside it.
        -- If that support moves/unanchors, the knife follows; if it is deleted,
        -- the watcher releases the knife so it falls and sticks to another surface.
        if surfacePart and surfacePart:IsA("BasePart") and surfacePart:IsDescendantOf(W) then
            stickKnifeToSurface(knife, pos, normal, surfacePart, false)
        else
            -- Terrain/unsupported targets have no BasePart to weld to.
            stickKnifeToSurface(knife, pos, normal, nil, false)
        end
    end

    -- Every TPPoint label is physically welded to its knife. For Radar points,
    -- the knife is attached to the player's head until it drops on death.
    attachLabelToKnife(anchor, knife)

    -- Keep the original single spawn sound for standard TPPoints and player Radar.
    snd(137951817204948, 1)

    connect(labelButton.MouseButton1Click, function()
        if guiClosed then return end

        local now = tick()

        if now - t2 <= W_T and t2 ~= 0 then
            local targetPos = knife and knife.Parent and knife:GetPivot().Position
                or (anchor.Position - Vector3.new(0, 10, 0))
            tp(targetPos, isPl, targetPlayer)
            t2 = 0
        else
            t2 = now
        end
    end)

    if isPl then
        table.insert(bk.playerPoints, {
            Pos = pos,
            PlName = targetPlayer.Name,
            PlayerObj = targetPlayer,
            Ancor = anchor,
            Knife = knife,
            KnifeCharacter = targetPlayer.Character
        })
    else
        table.insert(bk.mapPoints, {
            Pos = pos,
            Idx = index,
            Ancor = anchor,
            Knife = knife,
            SurfaceNormal = surfaceNormal or Vector3.yAxis,
            SurfacePart = surfacePart
        })
    end

    rebuildLists()
end

local function updatePage()
    if not MF or guiClosed then return end

    scroll1.Visible = bk.curPage == 1 and not inConfigMode
    scroll2.Visible = bk.curPage == 2 and not inConfigMode
    scroll3.Visible = bk.curPage == 3 and not inConfigMode
    navLeft.Visible = bk.curPage > 1 and not inConfigMode
    navRight.Visible = bk.curPage < 3 and not inConfigMode

    if bk.curPage == 1 then
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "MAPA"
        navLabel.TextColor3 = THEME.red
        createBtn.BackgroundColor3 = THEME.red
    elseif bk.curPage == 2 then
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "PLAYERS"
        navLabel.TextColor3 = THEME.blue
        createBtn.BackgroundColor3 = THEME.blue
    else
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "SPECTATE"
        navLabel.TextColor3 = THEME.green
        createBtn.BackgroundColor3 = THEME.green
    end
end

local function toggleConfigMode(state)
    if guiClosed then return end

    inConfigMode = state
    configFrame.Visible = state

    if state then
        local pos = (safe_data and safe_data.TargetPos) or bk.safe_pos

        if not pos then
            c = pl.Character
            local root = c and c:FindFirstChild(HRP)
            pos = root and root.Position or Vector3.zero
        end

        hpInput.Text = tostring(math.floor(bk.safe_hp * 100 + 0.5))
        xInput.Text = tostring(math.floor(pos.X * 100) / 100)
        yInput.Text = tostring(math.floor(pos.Y * 100) / 100)
        zInput.Text = tostring(math.floor(pos.Z * 100) / 100)
    end

    scroll1.Visible = not state and bk.curPage == 1
    scroll2.Visible = not state and bk.curPage == 2
    scroll3.Visible = not state and bk.curPage == 3

    createBtn.Visible = not state
    radarBtn.Visible = not state
    refreshBtn.Visible = not state
    safeBtn.Visible = not state
    navLeft.Visible = not state and bk.curPage > 1
    navRight.Visible = not state and bk.curPage < 3
    navLabel.Visible = not state
    cfgBtn.Visible = not state
end

local function closeThisInstance()
    if guiClosed then return end

    guiClosed = true
    endSpectate()

    for _, item in ipairs(bk.mapPoints) do
        if item.Ancor then item.Ancor:Destroy() end
        if item.Knife then item.Knife:Destroy() end
    end

    for _, item in ipairs(bk.playerPoints) do
        if item.Ancor then item.Ancor:Destroy() end
        if item.Knife then item.Knife:Destroy() end
    end

    if safe_data then
        if safe_data.Cube then safe_data.Cube:Destroy() end
        if safe_data.Ancor then safe_data.Ancor:Destroy() end
        safe_data = nil
    end

    if zone then
        zone:Destroy()
        zone = nil
    end

    bk.mapPoints = {}
    bk.playerPoints = {}

    disconnectOwnConnections()

    if sg then
        sg:Destroy()
        sg = nil
    end
end

buildGui = function()
    if guiClosed then return end

    sg = Instance.new("ScreenGui")
    sg.Name = "TP_Tabs_Gui_" .. TP_INSTANCE_ID
    sg:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
    sg:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.Parent = pg

    MF = Instance.new("Frame")
    MF.Name = "MainFrame_" .. TP_INSTANCE_ID
    MF.Size = UDim2.new(0, 260, 0, 320)
    MF.Position = UDim2.new(0.5, -130, 0.5, -160)
    MF.BackgroundColor3 = THEME.background
    MF.BorderSizePixel = 0
    MF.Active = true
    MF.Parent = sg

    roundify(MF, 12)
    outline(MF, THEME.border, 1.5)

    local header = Instance.new("Frame")
    header.Name = "Header_" .. TP_INSTANCE_ID
    header.Active = true
    header.Selectable = false
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundColor3 = THEME.header
    header.BorderSizePixel = 0
    header.Parent = MF
    roundify(header, 12)

    local headerCover = Instance.new("Frame")
    headerCover.Size = UDim2.new(1, 0, 0, 12)
    headerCover.Position = UDim2.new(0, 0, 1, -12)
    headerCover.BackgroundColor3 = THEME.header
    headerCover.BorderSizePixel = 0
    headerCover.Parent = header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title_" .. TP_INSTANCE_ID
    titleLabel.Size = UDim2.new(1, -145, 0, 24)
    titleLabel.Position = UDim2.new(0, 12, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "tppointsGUIV2"
    titleLabel.TextColor3 = THEME.text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -145, 0, 13)
    subtitle.Position = UDim2.new(0, 13, 0, 29)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "TELEPORT / CONTROL PANEL"
    subtitle.TextColor3 = THEME.muted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 7
    subtitle.Parent = header

    -- Transparent header surface retained for compatibility; drag input is now
    -- bound to the entire panel and all its GUI descendants, not just this area.
    local dragHandle = Instance.new("TextButton")
    dragHandle.Name = "TouchDragHandle_" .. TP_INSTANCE_ID
    dragHandle.Size = UDim2.new(1, -160, 1, 0)
    dragHandle.Position = UDim2.new(0, 0, 0, 0)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Text = ""
    dragHandle.AutoButtonColor = false
    dragHandle.Active = true
    dragHandle.Selectable = false
    dragHandle.ZIndex = 5
    dragHandle.Parent = header

    local accentLine = Instance.new("Frame")
    accentLine.Name = "AccentLine_" .. TP_INSTANCE_ID
    accentLine.Size = UDim2.new(1, -20, 0, 2)
    accentLine.Position = UDim2.new(0, 10, 0, 51)
    accentLine.BackgroundColor3 = THEME.red
    accentLine.BorderSizePixel = 0
    accentLine.Parent = MF
    roundify(accentLine, 2)

    cfgBtn = Instance.new("TextButton")
    cfgBtn.Name = "ConfigButton_" .. TP_INSTANCE_ID
    cfgBtn.Size = UDim2.new(0, 77, 0, 27)
    cfgBtn.Position = UDim2.new(1, -151, 0, 12)
    cfgBtn.Text = "⚙ Config"
    cfgBtn.Parent = header
    styleButton(cfgBtn, THEME.button)
    cfgBtn.TextSize = 9

    minBtn = Instance.new("TextButton")
    minBtn.Name = "MinimizeButton_" .. TP_INSTANCE_ID
    minBtn.Size = UDim2.new(0, 27, 0, 27)
    minBtn.Position = UDim2.new(1, -65, 0, 12)
    minBtn.Text = "−"
    minBtn.Parent = header
    styleButton(minBtn, THEME.button)
    minBtn.TextSize = 15

    closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton_" .. TP_INSTANCE_ID
    closeBtn.Size = UDim2.new(0, 27, 0, 27)
    closeBtn.Position = UDim2.new(1, -33, 0, 12)
    closeBtn.Text = "×"
    closeBtn.Parent = header
    styleButton(closeBtn, THEME.red)
    closeBtn.TextSize = 16

    local function makeScroll(name)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = name .. "_" .. TP_INSTANCE_ID
        scroll.Size = UDim2.new(1, -20, 0, 94)
        scroll.Position = UDim2.new(0, 10, 0, 115)
        scroll.BackgroundColor3 = THEME.panel
        scroll.BackgroundTransparency = 0
        scroll.BorderSizePixel = 0
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = THEME.muted
        scroll.Parent = MF

        roundify(scroll, 8)
        outline(scroll, THEME.border, 1)

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 5)
        padding.PaddingBottom = UDim.new(0, 5)
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = scroll

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        return scroll, layout
    end

    createBtn = Instance.new("TextButton")
    createBtn.Name = "CreatePointButton_" .. TP_INSTANCE_ID
    createBtn.Size = UDim2.new(0.5, -15, 0, 28)
    createBtn.Position = UDim2.new(0, 10, 0, 63)
    createBtn.Text = "＋ Criar ponto"
    createBtn.Parent = MF
    styleButton(createBtn, THEME.red)
    createBtn.TextSize = 10

    radarBtn = Instance.new("TextButton")
    radarBtn.Name = "RadarButton_" .. TP_INSTANCE_ID
    radarBtn.Size = UDim2.new(0.5, -15, 0, 28)
    radarBtn.Position = UDim2.new(0.5, 5, 0, 63)
    radarBtn.Text = "◎ Radar players"
    radarBtn.Parent = MF
    styleButton(radarBtn, THEME.button)
    radarBtn.TextSize = 10

    local sectionCaption = Instance.new("TextLabel")
    sectionCaption.Size = UDim2.new(1, -20, 0, 14)
    sectionCaption.Position = UDim2.new(0, 11, 0, 96)
    sectionCaption.BackgroundTransparency = 1
    sectionCaption.Text = "PONTOS SALVOS"
    sectionCaption.TextColor3 = THEME.muted
    sectionCaption.TextXAlignment = Enum.TextXAlignment.Left
    sectionCaption.Font = Enum.Font.GothamBold
    sectionCaption.TextSize = 8
    sectionCaption.Parent = MF

    scroll1, layout1 = makeScroll("MapPoints")
    scroll2, layout2 = makeScroll("PlayerPoints")
    scroll3, layout3 = makeScroll("SpectatePoints")

    scroll2.Visible = false
    scroll3.Visible = false

    refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshButton_" .. TP_INSTANCE_ID
    refreshBtn.Size = UDim2.new(0.5, -15, 0, 27)
    refreshBtn.Position = UDim2.new(0, 10, 0, 217)
    refreshBtn.Text = "↻ Limpar tudo"
    refreshBtn.Parent = MF
    styleButton(refreshBtn, THEME.button)
    refreshBtn.TextColor3 = Color3.fromRGB(255, 190, 90)
    refreshBtn.TextSize = 10

    safeBtn = Instance.new("TextButton")
    safeBtn.Name = "SafeButton_" .. TP_INSTANCE_ID
    safeBtn.Size = UDim2.new(0.5, -15, 0, 27)
    safeBtn.Position = UDim2.new(0.5, 5, 0, 217)
    safeBtn.Text = "◇ Safe Orb"
    safeBtn.Parent = MF
    styleButton(safeBtn, THEME.button)
    safeBtn.TextColor3 = Color3.fromRGB(150, 175, 255)
    safeBtn.TextSize = 10

    navLeft = Instance.new("TextButton")
    navLeft.Name = "NavLeft_" .. TP_INSTANCE_ID
    navLeft.Size = UDim2.new(0, 30, 0, 27)
    navLeft.Position = UDim2.new(0, 10, 0, 282)
    navLeft.Text = "‹"
    navLeft.Parent = MF
    styleButton(navLeft, THEME.button)
    navLeft.TextSize = 18

    navLabel = Instance.new("TextLabel")
    navLabel.Name = "NavLabel_" .. TP_INSTANCE_ID
    navLabel.Size = UDim2.new(1, -84, 0, 27)
    navLabel.Position = UDim2.new(0, 42, 0, 282)
    navLabel.BackgroundTransparency = 1
    navLabel.TextColor3 = THEME.text
    navLabel.Font = Enum.Font.GothamBold
    navLabel.TextSize = 10
    navLabel.Parent = MF

    navRight = Instance.new("TextButton")
    navRight.Name = "NavRight_" .. TP_INSTANCE_ID
    navRight.Size = UDim2.new(0, 30, 0, 27)
    navRight.Position = UDim2.new(1, -40, 0, 282)
    navRight.Text = "›"
    navRight.Parent = MF
    styleButton(navRight, THEME.button)
    navRight.TextSize = 18

    configFrame = Instance.new("Frame")
    configFrame.Name = "ConfigFrame_" .. TP_INSTANCE_ID
    configFrame.Size = UDim2.new(1, -20, 0, 190)
    configFrame.Position = UDim2.new(0, 10, 0, 112)
    configFrame.BackgroundColor3 = THEME.panel
    configFrame.BorderSizePixel = 0
    configFrame.Visible = false
    configFrame.Parent = MF
    roundify(configFrame, 8)
    outline(configFrame, THEME.border, 1)

    cfgLabel = Instance.new("TextLabel")
    cfgLabel.Name = "ConfigLabel_" .. TP_INSTANCE_ID
    cfgLabel.Size = UDim2.new(1, -20, 0, 22)
    cfgLabel.Position = UDim2.new(0, 10, 0, 8)
    cfgLabel.BackgroundTransparency = 1
    cfgLabel.Text = "HP DE RESGATE (%)"
    cfgLabel.TextColor3 = THEME.text
    cfgLabel.Font = Enum.Font.GothamBold
    cfgLabel.TextSize = 10
    cfgLabel.TextXAlignment = Enum.TextXAlignment.Left
    cfgLabel.Parent = configFrame

    hpInput = Instance.new("TextBox")
    hpInput.Name = "HPInput_" .. TP_INSTANCE_ID
    hpInput.Size = UDim2.new(1, -20, 0, 27)
    hpInput.Position = UDim2.new(0, 10, 0, 32)
    hpInput.BackgroundColor3 = THEME.input
    hpInput.Text = tostring(math.floor(bk.safe_hp * 100 + 0.5))
    hpInput.PlaceholderText = "Ex.: 30"
    hpInput.TextColor3 = THEME.text
    hpInput.Font = Enum.Font.Gotham
    hpInput.TextSize = 11
    hpInput.ClearTextOnFocus = false
    hpInput.Parent = configFrame
    roundify(hpInput, 6)

    local coordLabel = Instance.new("TextLabel")
    coordLabel.Name = "CoordLabel_" .. TP_INSTANCE_ID
    coordLabel.Size = UDim2.new(1, -20, 0, 22)
    coordLabel.Position = UDim2.new(0, 10, 0, 64)
    coordLabel.BackgroundTransparency = 1
    coordLabel.Text = "DESTINO DO TELEPORTE (X / Y / Z)"
    coordLabel.TextColor3 = THEME.text
    coordLabel.Font = Enum.Font.GothamBold
    coordLabel.TextSize = 8
    coordLabel.TextXAlignment = Enum.TextXAlignment.Left
    coordLabel.Parent = configFrame

    local function makeCoordInput(name, x, placeholder)
        local box = Instance.new("TextBox")
        box.Name = name .. "_" .. TP_INSTANCE_ID
        box.Size = UDim2.new(0.333, -8, 0, 27)
        box.Position = UDim2.new(0, x, 0, 88)
        box.BackgroundColor3 = THEME.input
        box.TextColor3 = THEME.text
        box.PlaceholderText = placeholder
        box.Text = ""
        box.Font = Enum.Font.Gotham
        box.TextSize = 10
        box.ClearTextOnFocus = false
        box.Parent = configFrame
        roundify(box, 6)
        return box
    end

    xInput = makeCoordInput("SafeX", 10, "X")
    yInput = makeCoordInput("SafeY", 82, "Y")
    zInput = makeCoordInput("SafeZ", 154, "Z")

    hpSaveBtn = Instance.new("TextButton")
    hpSaveBtn.Name = "HPSaveButton_" .. TP_INSTANCE_ID
    hpSaveBtn.Size = UDim2.new(0.5, -15, 0, 28)
    hpSaveBtn.Position = UDim2.new(0, 10, 0, 127)
    hpSaveBtn.Text = "Salvar"
    hpSaveBtn.Parent = configFrame
    styleButton(hpSaveBtn, THEME.green)
    hpSaveBtn.TextSize = 10

    cfgBackBtn = Instance.new("TextButton")
    cfgBackBtn.Name = "ConfigBackButton_" .. TP_INSTANCE_ID
    cfgBackBtn.Size = UDim2.new(0.5, -15, 0, 28)
    cfgBackBtn.Position = UDim2.new(0.5, 5, 0, 127)
    cfgBackBtn.Text = "Voltar"
    cfgBackBtn.Parent = configFrame
    styleButton(cfgBackBtn, THEME.red)
    cfgBackBtn.TextSize = 10

    -- Arraste pelo painel inteiro, respeitando visibilidade e gestos multitouch.
    -- Somente o toque que começou no painel pode movê-lo; toques secundários
    -- (por exemplo, o dedo no joystick) são ignorados.
    local function dragFrame(frame)
        local dragging = false
        local dragStartPosition = nil
        local frameStartUDim = nil
        local activeTouch = nil
        local boundTargets = setmetatable({}, {__mode = "k"})

        local function isTargetCurrentlyVisible(target)
            if guiClosed or not frame.Visible or not frameOpen then
                -- Quando minimizado, somente o cabeçalho continua sendo uma área válida.
                if guiClosed or not frame.Visible then return false end
                local current = target
                while current and current ~= frame do
                    if current == header then return true end
                    current = current.Parent
                end
                return false
            end

            local current = target
            while current do
                if current:IsA("GuiObject") and not current.Visible then
                    return false
                end
                if current == frame then break end
                current = current.Parent
            end
            return current == frame
        end

        local function applyDrag(pointerPosition)
            if not dragging or guiClosed or not frame.Parent or not frame.Visible then return end
            local delta = pointerPosition - dragStartPosition
            frame.Position = UDim2.new(
                frameStartUDim.X.Scale,
                frameStartUDim.X.Offset + delta.X,
                frameStartUDim.Y.Scale,
                frameStartUDim.Y.Offset + delta.Y
            )
        end

        local function beginDrag(input, target)
            if guiClosed or dragging or not isTargetCurrentlyVisible(target) then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            -- Garante que o toque começou dentro da parte atualmente visível do painel.
            local p = Vector2.new(input.Position.X, input.Position.Y)
            local topLeft = frame.AbsolutePosition
            local size = frame.AbsoluteSize
            if p.X < topLeft.X or p.Y < topLeft.Y
                or p.X > topLeft.X + size.X or p.Y > topLeft.Y + size.Y then
                return
            end

            dragging = true
            dragStartPosition = p
            frameStartUDim = frame.Position
            activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil

            connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    if activeTouch == input then activeTouch = nil end
                    dragging = false
                end
            end)
        end

        local function isInsideScrollingList(target)
            local current = target
            while current and current ~= frame do
                if current:IsA("ScrollingFrame") then return true end
                current = current.Parent
            end
            return false
        end

        local function bindDragTarget(target)
            if not target:IsA("GuiObject") or boundTargets[target] then return end
            boundTargets[target] = true
            -- Gesto iniciado numa lista pertence à lista, não ao painel.
            if isInsideScrollingList(target) then return end
            connect(target.InputBegan, function(input)
                beginDrag(input, target)
            end)
        end

        bindDragTarget(frame)
        for _, descendant in ipairs(frame:GetDescendants()) do
            bindDragTarget(descendant)
        end
        connect(frame.DescendantAdded, bindDragTarget)

        connect(U.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement and activeTouch == nil then
                applyDrag(Vector2.new(input.Position.X, input.Position.Y))
            elseif input.UserInputType == Enum.UserInputType.Touch and activeTouch ~= nil and input == activeTouch then
                applyDrag(Vector2.new(input.Position.X, input.Position.Y))
            end
        end)

        connect(U.TouchMoved, function(input)
            -- CRÍTICO: não usar qualquer TouchMoved; ignorar o segundo dedo/joystick.
            if dragging and activeTouch ~= nil and input == activeTouch then
                applyDrag(Vector2.new(input.Position.X, input.Position.Y))
            end
        end)
    end
    dragFrame(MF)

    connect(cfgBtn.MouseButton1Click, function()
        toggleConfigMode(true)
    end)

    connect(cfgBackBtn.MouseButton1Click, function()
        toggleConfigMode(false)
    end)

    connect(hpSaveBtn.MouseButton1Click, function()
        if guiClosed then return end

        local hpValue = tonumber(hpInput.Text)
        local x, y, z = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text)

        if not hpValue or not x or not y or not z then
            cfgLabel.Text = "Preencha HP e X / Y / Z!"
            cfgLabel.TextColor3 = THEME.red
            return
        end

        bk.safe_hp = math.clamp(hpValue / 100, 0.01, 0.99)

        local newPos = Vector3.new(x, y, z)
        bk.safe_pos = newPos

        if safe_data then
            safe_data.TargetPos = newPos

            if safe_data.Knife and safe_data.Knife.Parent then
                removeKnifeWeld(safe_data.Knife)
                safe_data.Knife:SetAttribute("Dropped", false)
                setKnifeState(safe_data.Knife, true, false)
                safe_data.Knife:PivotTo(CFrame.new(newPos + Vector3.new(0, 25, 0)))
                dropKnifeOnSurface(safe_data.Knife)
            end

        end

        cfgLabel.Text = "HP DE RESGATE (%)"
        cfgLabel.TextColor3 = THEME.text
        toggleConfigMode(false)
    end)

    connect(navLeft.MouseButton1Click, function()
        if guiClosed then return end

        if specActive then
            jumpSpectate(-1)
        elseif bk.curPage > 1 then
            bk.curPage -= 1
            updatePage()
        end
    end)

    connect(navRight.MouseButton1Click, function()
        if guiClosed then return end

        if specActive then
            jumpSpectate(1)
        elseif bk.curPage < 3 then
            bk.curPage += 1
            updatePage()
        end
    end)

    connect(createBtn.MouseButton1Click, function()
        if guiClosed then return end

        bk.ok = not bk.ok
        createBtn.Text = bk.ok and "✓ Criar ponto: ON" or "＋ Criar ponto"
        createBtn.BackgroundColor3 = bk.ok and THEME.green
            or (bk.curPage == 1 and THEME.red
            or bk.curPage == 2 and THEME.blue or THEME.green)
    end)

    connect(radarBtn.MouseButton1Click, function()
        if guiClosed then return end

        bk.pl_rad = not bk.pl_rad
        radarBtn.BackgroundColor3 = bk.pl_rad and THEME.blue or THEME.button

        if bk.pl_rad then
            if not zone then
                zone = Instance.new("Part")
                zone.Name = "set_tppoint_inplayer_" .. TP_INSTANCE_ID
                zone:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
                zone:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
                zone.Size = Vector3.new(50, 0.2, 50)
                zone.Material = Enum.Material.Neon
                zone.Color = THEME.blue
                zone.Transparency = 0.8
                zone.CanCollide = false
                zone.Anchored = true
                zone.Parent = W
            end
        elseif zone then
            zone:Destroy()
            zone = nil
        end
    end)

    connect(safeBtn.MouseButton1Click, function()
        if guiClosed then return end

        c = pl.Character
        local root = c and c:FindFirstChild(HRP)
        if not root then return end

        if safe_data then
            if safe_data.Cube then safe_data.Cube:Destroy() end
            if safe_data.Ancor then safe_data.Ancor:Destroy() end
            safe_data = nil
        end

        local safePos = root.Position
        bk.safe_pos, bk.sf_act = safePos, true
        snd(1841353894, 1)

        local safeKnife = createDetailedKnife(safePos + Vector3.new(0, 25, 0), Color3.fromRGB(12, 12, 16), "TP_SafePointKnife_" .. TP_INSTANCE_ID, 1.25)
        safeKnife:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
        safeKnife:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
        -- SafePoint follows the same drop-and-stick physics as a thrown knife.
        dropKnifeOnSurface(safeKnife)

        local anchor, label = makeLabel3D(safePos + Vector3.new(0, 25, 0), "SAFE_POINT", false)
        label.TextColor3 = THEME.green
        attachLabelToKnife(anchor, safeKnife)

        safe_data = {
            Knife = safeKnife,
            Cube = safeKnife,
            Ancor = anchor,
            TargetPos = safePos
        }

        connect(label.MouseButton1Click, function()
            if guiClosed then return end

            local now = tick()

            if now - t2 <= W_T and t2 ~= 0 then
                local targetPos = safe_data and safe_data.TargetPos
                if targetPos then tp(targetPos, false, nil) end
                t2 = 0
            else
                t2 = now
            end
        end)
    end)

    connect(refreshBtn.MouseButton1Click, function()
        if guiClosed then return end

        for _, item in ipairs(bk.mapPoints) do
            if item.Ancor then item.Ancor:Destroy() end
            if item.Knife then item.Knife:Destroy() end
        end

        for _, item in ipairs(bk.playerPoints) do
            if item.Ancor then item.Ancor:Destroy() end
            if item.Knife then item.Knife:Destroy() end
        end

        if safe_data then
            if safe_data.Knife then safe_data.Knife:Destroy() end
            if safe_data.Ancor then safe_data.Ancor:Destroy() end
        end

        if zone then
            zone:Destroy()
            zone = nil
        end

        bk.mapPoints = {}
        bk.playerPoints = {}
        bk.cnt = 0
        bk.sf_act = false
        bk.safe_pos = nil
        bk.pl_rad = false
        safe_data = nil

        radarBtn.BackgroundColor3 = THEME.button
        endSpectate()
        rebuildLists()
    end)

    local function setUiActive(value)
        cfgBtn.Visible = value
        closeBtn.Visible = true

        createBtn.Visible = value and not inConfigMode
        radarBtn.Visible = value and not inConfigMode
        refreshBtn.Visible = value and not inConfigMode
        safeBtn.Visible = value and not inConfigMode

        navLabel.Visible = value and not inConfigMode
        navLeft.Visible = value and bk.curPage > 1 and not inConfigMode
        navRight.Visible = value and bk.curPage < 3 and not inConfigMode

        configFrame.Visible = value and inConfigMode

        scroll1.Visible = value and bk.curPage == 1 and not inConfigMode
        scroll2.Visible = value and bk.curPage == 2 and not inConfigMode
        scroll3.Visible = value and bk.curPage == 3 and not inConfigMode

        hpInput.Active = value and inConfigMode
        xInput.Active = value and inConfigMode
        yInput.Active = value and inConfigMode
        zInput.Active = value and inConfigMode

        hpSaveBtn.Active = value and inConfigMode
        cfgBackBtn.Active = value and inConfigMode
    end

    connect(minBtn.MouseButton1Click, function()
        if guiClosed then return end

        frameOpen = not frameOpen
        minBtn.Text = frameOpen and "−" or "+"

        if frameOpen then
            MF.Size = UDim2.new(0, 260, 0, 320)
            setUiActive(true)
            updatePage()
        else
            setUiActive(false)
            MF.Size = UDim2.new(0, 260, 0, 52)
        end
    end)

    connect(closeBtn.MouseButton1Click, function()
        closeThisInstance()
    end)

    updatePage()
    rebuildLists()
end

connect(m.Button1Down, function()
    if guiClosed or not bk.ok then return end

    local now = tick()
    if now - t3 < CD then return end

    if t1 == 0 or now - t1 > W_T then
        t1 = now
        return
    end

    t1, t3 = 0, now

    local hit = m.Hit
    if not hit then return end

    bk.cnt = #bk.mapPoints + 1
    local normal = surfaceNormalFromMouse()
    addListButton(hit.Position, false, nil, bk.cnt, normal, m.Target)
end)

connect(R.Heartbeat, function()
    if guiClosed then return end

    c = pl.Character

    local root = c and c:FindFirstChild(HRP)
    local hum = c and c:FindFirstChildOfClass("Humanoid")

    if not root or not hum then return end

    if safe_data and safe_data.TargetPos
        and hum.Health > 0 and hum.MaxHealth > 0 then

        local now = tick()

        if hum.Health / hum.MaxHealth <= bk.safe_hp
            and now - t_sf >= SF_CD then

            t_sf = now
            tp(safe_data.TargetPos, false, nil)
        end
    end

    if bk.pl_rad then
        if zone then
            zone.Position = root.Position + Vector3.new(0, -3, 0)
        end

        local now = tick()

        if now - t_pl >= PL_CD then
            t_pl = now

            for _, other in ipairs(P:GetPlayers()) do
                if other ~= pl and other.Character
                    and other.Character:FindFirstChild(HRP) then

                    local otherRoot = other.Character[HRP]

                    if (root.Position - otherRoot.Position).Magnitude <= 25 then
                        local found = false

                        for _, item in ipairs(bk.playerPoints) do
                            if item.PlName == other.Name then
                                found = true
                                break
                            end
                        end

                        if not found then
                            snd(1841353894, 1.5)
                            addListButton(otherRoot.Position, true, other, 0)
                        end
                    end
                end
            end
        end
    end

    -- Map TP labels/targets follow their knife pivot if the knife is moved or thrown.
    for _, item in ipairs(bk.mapPoints) do
        if item.Knife and item.Knife.Parent then
            local knifePos = item.Knife:GetPivot().Position
            item.Pos = knifePos
        end
    end

    -- SafePoint's marker and teleport target remain attached to its knife.
    if safe_data and safe_data.Knife and safe_data.Knife.Parent then
        local safeKnifePos = safe_data.Knife:GetPivot().Position
        safe_data.TargetPos = safeKnifePos
    end

    for _, item in ipairs(bk.playerPoints) do
        local currentCharacter = item.PlayerObj and item.PlayerObj.Character
        local playerRoot = currentCharacter and currentCharacter:FindFirstChild(HRP)
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")

        if item.Knife and item.Knife.Parent then
            if playerRoot and currentHumanoid and currentHumanoid.Health > 0 then
                item.Pos = playerRoot.Position
                if item.KnifeCharacter ~= currentCharacter or item.Knife:GetAttribute("Dropped") then
                    item.Knife:SetAttribute("Dropped", false)
                    if attachKnifeToHead(item.Knife, currentCharacter, 1.05) then
                        item.KnifeCharacter = currentCharacter
                    end
                end
            else
                -- If the player dies, respawns, or their character disappears,
                -- the knife and its welded TP label fall together until they stick.
                if not item.Knife:GetAttribute("Dropped") then
                    dropKnifeOnSurface(item.Knife)
                end
                item.Pos = item.Knife:GetPivot().Position
            end
        end
    end
end)

connect(pl.CharacterAdded, function(newCharacter)
    if guiClosed then return end
    c = newCharacter
end)

buildGui()

-- Limpa a interface e os objetos quando o jogador
-- começa a sair deste jogo por teleporte.
connect(pl.OnTeleport, function(state)
    if state == Enum.TeleportState.Started
        or state == Enum.TeleportState.WaitingForServer then

        closeThisInstance()
    end
end)
