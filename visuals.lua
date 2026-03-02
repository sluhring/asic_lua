-- Visuals: ESP, FOV circle (combat aim FOV), etc.
-- FOV circle is the combat aim FOV; enable/radius come from getgenv().AsicVisuals or default.

local default = {
    ["2dbox"] = { color = Color3.fromRGB(255, 255, 255), enable = true },
    ["name"] = { enable = true, placement = "Top" },
    ["studs"] = { enable = true },
    ["tool"] = { enable = true, placement = "Bottom" },
    ["fov"] = { enable = true },
    ["flags"] = { enable = true, placement = "Right" },
    ["skeleton"] = { enable = true, color = Color3.new(1, 1, 1), outlineEnabled = true, outlineColor = Color3.new(0, 0, 0), lineThickness = 1, outlineThickness = 3 },
    ["trail"] = { enable = true, rgb = Color3.fromRGB(255, 255, 255), thickness = 1 },
    ["highlight"] = { enable = true, fillColor = Color3.fromRGB(128, 128, 128), outlineColor = Color3.fromRGB(0, 0, 0), fillTransparency = 0.5, outlineTransparency = 0 }
}

local ps = game:GetService("Players")
local lp = ps.LocalPlayer
local rs = game:GetService("RunService")
local c = workspace.CurrentCamera
local userInputService = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")

local worldToViewportPoint = c.WorldToViewportPoint
local HeadOff = Vector3.new(0, 0.5, 0)
local LegOff = Vector3.new(0, 3, 0)
local boxScaleFactor = 1.2
local boxCache = {}
local flagsCache = {}
local stackingInfo = {}
local playerESP = {}

local function getFOVConfig()
    local g = getgenv()
    if g.AsicVisuals then
        return g.AsicVisuals.fov_enable ~= false, tonumber(g.AsicVisuals.fov_radius) or 160
    end
    return default.fov.enable, 160
end

local function getdistancefc(part)
    return (part.Position - c.CFrame.Position).Magnitude
end

local function getMovementState(humanoid, hrp)
    local velocity = hrp.Velocity
    if velocity.Y > 1 then
        return "jumping"
    end
    if velocity.Y < -1 then
        return "falling"
    end
    local horizontalSpeed = math.sqrt(velocity.X^2 + velocity.Z^2)
    if horizontalSpeed < 0.5 then
        return "idling"
    elseif horizontalSpeed <= 15 then
        return "walking"
    else
        return "running"
    end
end

local function getPosition(placement, boxPos, boxSize, userId, elementType)
    if not stackingInfo[userId] then
        stackingInfo[userId] = {
            Top = { count = 0, elements = {} },
            Bottom = { count = 0, elements = {} },
            Left = { count = 0, elements = {} },
            Right = { count = 0, elements = {} }
        }
    end
    if not stackingInfo[userId][placement].elements[elementType] then
        stackingInfo[userId][placement].count = stackingInfo[userId][placement].count + 1
        stackingInfo[userId][placement].elements[elementType] = stackingInfo[userId][placement].count
    end
    local stackPosition = stackingInfo[userId][placement].elements[elementType]
    local stackOffset = (stackPosition - 1) * 15
    if placement == "Top" then
        return Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y - 20 - stackOffset), true
    elseif placement == "Bottom" then
        return Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y + boxSize.Y + 10 + stackOffset), true
    elseif placement == "Left" then
        return Vector2.new(boxPos.X - 10, boxPos.Y + boxSize.Y/2 + stackOffset), false
    elseif placement == "Right" then
        return Vector2.new(boxPos.X + boxSize.X + 10, boxPos.Y + boxSize.Y/2 + stackOffset), false
    else
        return Vector2.new(boxPos.X + boxSize.X/2, boxPos.Y - 20), true
    end
end

local function resetStackingInfo(userId)
    stackingInfo[userId] = nil
end

local function esp(p, cr)
    local h = cr:WaitForChild("Humanoid")
    local head = cr:WaitForChild("Head")
    local text = Drawing.new("Text")
    text.Visible = false
    text.Outline = true 
    text.Font = 2
    text.Color = Color3.fromRGB(255,255,255)
    text.Size = 13
    local c1, c2, c3
    local function dc()
        text.Visible = false
        text:Remove()
        resetStackingInfo(p.UserId)
        if c1 then c1:Disconnect() end
        if c2 then c2:Disconnect() end
        if c3 then c3:Disconnect() end
    end
    c2 = cr.AncestryChanged:Connect(function(_, parent)
        if not parent then dc() end
    end)
    c3 = h.HealthChanged:Connect(function(v)
        if v <= 0 or h:GetState() == Enum.HumanoidStateType.Dead then dc() end
    end)
    c1 = rs.RenderStepped:Connect(function()
        if not boxCache[p.UserId] then return end
        local boxPos = boxCache[p.UserId].Box.Position
        local boxSize = boxCache[p.UserId].Box.Size
        if boxCache[p.UserId].Box.Visible then
            local pos, centered = getPosition(default.name.placement, boxPos, boxSize, p.UserId, "name")
            text.Position = pos
            text.Center = centered
            text.Text = p.Name .. ' (' .. tostring(math.floor(getdistancefc(head))) .. ' studs)'
            text.Visible = default.studs.enable
        else
            text.Visible = false
        end
    end)
end

local function flagsEsp(p, cr)
    local h = cr:WaitForChild("Humanoid")
    local hrp = cr:WaitForChild("HumanoidRootPart")
    local text = Drawing.new("Text")
    text.Visible = false
    text.Outline = true 
    text.Font = 2
    text.Color = Color3.fromRGB(255,255,255)
    text.Size = 13
    flagsCache[p.UserId] = text
    local c1, c2, c3
    local function dc()
        text.Visible = false
        text:Remove()
        flagsCache[p.UserId] = nil
        if c1 then c1:Disconnect() end
        if c2 then c2:Disconnect() end
        if c3 then c3:Disconnect() end
    end
    c2 = cr.AncestryChanged:Connect(function(_, parent)
        if not parent then dc() end
    end)
    c3 = h.HealthChanged:Connect(function(v)
        if v <= 0 or h:GetState() == Enum.HumanoidStateType.Dead then dc() end
    end)
    c1 = rs.RenderStepped:Connect(function()
        if not boxCache[p.UserId] then return end
        local boxPos = boxCache[p.UserId].Box.Position
        local boxSize = boxCache[p.UserId].Box.Size
        if boxCache[p.UserId].Box.Visible then
            local movementState = getMovementState(h, hrp)
            local pos, centered = getPosition(default.flags.placement, boxPos, boxSize, p.UserId, "flags")
            text.Position = pos
            text.Center = centered
            text.Text = "[" .. movementState .. "]"
            text.Visible = default.flags.enable
        else
            text.Visible = false
        end
    end)
end

local function updateBoxESP(v)
    if not boxCache[v.UserId] then
        boxCache[v.UserId] = {
            BoxOutline = Drawing.new("Square"),
            Box = Drawing.new("Square")
        }
        local BoxOutline = boxCache[v.UserId].BoxOutline
        BoxOutline.Visible = false
        BoxOutline.Color = Color3.new(0, 0, 0)
        BoxOutline.Thickness = 3
        BoxOutline.Transparency = 1
        BoxOutline.Filled = false
        local Box = boxCache[v.UserId].Box
        Box.Visible = false
        Box.Color = default["2dbox"].color
        Box.Thickness = 1
        Box.Transparency = 1
        Box.Filled = false
    end
    
    local connection
    connection = rs.RenderStepped:Connect(function()
        if not v or not v.Character or 
           not v.Character:FindFirstChild("Humanoid") or 
           not v.Character:FindFirstChild("HumanoidRootPart") or 
           v.Character.Humanoid.Health <= 0 then
            if boxCache[v.UserId] then
                boxCache[v.UserId].BoxOutline.Visible = false
                boxCache[v.UserId].Box.Visible = false
            end
            if connection then
                connection:Disconnect()
            end
            return
        end
        
        local hrp = v.Character.HumanoidRootPart
        local head = v.Character:FindFirstChild("Head")
        if head then
            local headPos, headOnScreen = c:WorldToViewportPoint(head.Position + HeadOff)
            local footPos, footOnScreen = c:WorldToViewportPoint(hrp.Position - LegOff)
            local hrpPos, onScreen = c:WorldToViewportPoint(hrp.Position)
            if headOnScreen and footOnScreen and onScreen then
                local scaleFactor = 1000 / hrpPos.Z
                local width = hrp.Size.X * scaleFactor * boxScaleFactor * 1.1 * 1.2  
                local height = (headPos.Y - footPos.Y) * 1.1
                local centerX = hrpPos.X
                local centerY = (headPos.Y + footPos.Y) / 2
                local BoxOutline = boxCache[v.UserId].BoxOutline
                local Box = boxCache[v.UserId].Box
                BoxOutline.Size = Vector2.new(width, height)
                BoxOutline.Position = Vector2.new(centerX - width / 2, centerY - height / 2)
                BoxOutline.Visible = default["2dbox"].enable
                Box.Size = Vector2.new(width, height)
                Box.Position = Vector2.new(centerX - width / 2, centerY - height / 2)
                Box.Visible = default["2dbox"].enable
                Box.Color = default["2dbox"].color
            else
                boxCache[v.UserId].BoxOutline.Visible = false
                boxCache[v.UserId].Box.Visible = false
            end
        end
    end)
end

local function ftool(cr)
    for _, b in next, cr:GetChildren() do 
        if b.ClassName == 'Tool' then return tostring(b.Name) end
    end
    return 'empty'
end

local function toolEsp(p, cr)
    local h = cr:WaitForChild("Humanoid")
    local hrp = cr:WaitForChild("HumanoidRootPart")
    local text = Drawing.new('Text')
    text.Visible = false
    text.Outline = true
    text.Color = Color3.new(1, 1, 1)
    text.Font = 2
    text.Size = 13
    local c1, c2, c3
    local function dc()
        text.Visible = false
        text:Remove()
        if c1 then c1:Disconnect() end
        if c2 then c2:Disconnect() end
        if c3 then c3:Disconnect() end
    end
    c2 = cr.AncestryChanged:Connect(function(_, parent)
        if not parent then dc() end
    end)
    c3 = h.HealthChanged:Connect(function(v)
        if v <= 0 or h:GetState() == Enum.HumanoidStateType.Dead then dc() end
    end)
    c1 = rs.Heartbeat:Connect(function()
        if not boxCache[p.UserId] then return end
        local boxPos = boxCache[p.UserId].Box.Position
        local boxSize = boxCache[p.UserId].Box.Size
        if boxCache[p.UserId].Box.Visible then
            local pos, centered = getPosition(default.tool.placement, boxPos, boxSize, p.UserId, "tool")
            text.Position = pos
            text.Center = centered
            text.Text = '[ ' .. tostring(ftool(cr)) .. ' ]'
            text.Visible = default.tool.enable
        else
            text.Visible = false
        end
    end)
end

local function createTrail(character)
    if not default.trail.enable then return end
    
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
    if not humanoidRootPart then return end
    
    local attachment0 = Instance.new("Attachment")
    attachment0.Position = Vector3.new(0, 0, 0)
    attachment0.Name = "TrailAttachment0"
    attachment0.Parent = humanoidRootPart
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Position = Vector3.new(0, 0, -0.5)
    attachment1.Name = "TrailAttachment1"
    attachment1.Parent = humanoidRootPart
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.WidthScale = NumberSequence.new(default.trail.thickness)
    trail.Color = ColorSequence.new(default.trail.rgb)
    trail.Parent = humanoidRootPart
    
    return trail
end

local function createHighlight(player)
    if not playerESP[player] then
        playerESP[player] = {}
    end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = default.highlight.fillColor
    highlight.OutlineColor = default.highlight.outlineColor
    highlight.FillTransparency = default.highlight.fillTransparency
    highlight.OutlineTransparency = default.highlight.outlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = default.highlight.enable
    
    playerESP[player].Highlight = highlight
    return highlight
end

local function updateHighlightESP(player)
    if not playerESP[player] or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    
    if not humanoidRootPart or not humanoid then
        return
    end

    if playerESP[player].Highlight then
        if not playerESP[player].Highlight.Parent then
            playerESP[player].Highlight.Parent = character
        end
        
        playerESP[player].Highlight.Enabled = default.highlight.enable
        playerESP[player].Highlight.FillColor = default.highlight.fillColor
        playerESP[player].Highlight.OutlineColor = default.highlight.outlineColor
        playerESP[player].Highlight.FillTransparency = default.highlight.fillTransparency
        playerESP[player].Highlight.OutlineTransparency = default.highlight.outlineTransparency
    end
end

local R6_CONNECTIONS = {
    {'Head', 'Torso'},
    {'Torso', 'Left Arm'},
    {'Torso', 'Right Arm'},
    {'Torso', 'Left Leg'},
    {'Torso', 'Right Leg'}
}

local R15_CONNECTIONS = {
    {'Head', 'UpperTorso'},
    {'UpperTorso', 'LowerTorso'},
    {'UpperTorso', 'LeftUpperArm'},
    {'UpperTorso', 'RightUpperArm'},
    {'LeftUpperArm', 'LeftLowerArm'},
    {'LeftLowerArm', 'LeftHand'},
    {'RightUpperArm', 'RightLowerArm'},
    {'RightLowerArm', 'RightHand'},
    {'LowerTorso', 'LeftUpperLeg'},
    {'LowerTorso', 'RightUpperLeg'},
    {'LeftUpperLeg', 'LeftLowerLeg'},
    {'LeftLowerLeg', 'LeftFoot'},
    {'RightUpperLeg', 'RightLowerLeg'},
    {'RightLowerLeg', 'RightFoot'}
}

local lines = {}
local outlines = {}

local function worldToScreen(part)
    local position, onScreen = c:WorldToViewportPoint(part.Position)
    return Vector2.new(position.X, position.Y), onScreen
end

local function getCharacterRig(character)
    return character:FindFirstChild('Torso') and 'R6' or 'R15'
end

local function clearLines()
    for _, line in ipairs(lines) do
        line:Remove()
    end
    for _, outline in ipairs(outlines) do
        outline:Remove()
    end
    lines = {}
    outlines = {}
end

local function drawSkeleton()
    clearLines()
    
    if not default.skeleton.enable then return end
    
    for _, player in ipairs(ps:GetPlayers()) do
        if player ~= lp then
            local character = player.Character
            
            if character then
                local humanoid = character:FindFirstChild('Humanoid')
                local rootPart = character:FindFirstChild('HumanoidRootPart')
                
                if humanoid and rootPart and humanoid.Health > 0 then
                    local connections = getCharacterRig(character) == 'R6' and R6_CONNECTIONS or R15_CONNECTIONS
                    
                    for _, connection in ipairs(connections) do
                        local fromPart = character:FindFirstChild(connection[1])
                        local toPart = character:FindFirstChild(connection[2])
                        
                        if fromPart and toPart then
                            local fromScreen, fromVisible = worldToScreen(fromPart)
                            local toScreen, toVisible = worldToScreen(toPart)
                            
                            if fromVisible and toVisible then
                                if default.skeleton.outlineEnabled then
                                    local outline = Drawing.new('Line')
                                    outline.From = fromScreen
                                    outline.To = toScreen
                                    outline.Color = default.skeleton.outlineColor
                                    outline.Thickness = default.skeleton.outlineThickness
                                    outline.Visible = true
                                    table.insert(outlines, outline)
                                end
                                
                                local line = Drawing.new('Line')
                                line.From = fromScreen
                                line.To = toScreen
                                line.Color = default.skeleton.color
                                line.Thickness = default.skeleton.lineThickness
                                line.Visible = true
                                table.insert(lines, line)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function playerRemoved(player)
    if playerESP[player] then
        if playerESP[player].Highlight then
            playerESP[player].Highlight:Destroy()
        end
        playerESP[player] = nil
    end
end

local function playerAdded(p)
    if p == lp then return end
    
    if not playerESP[p] then
        playerESP[p] = {}
        local highlight = createHighlight(p)
        
        local function characterAdded(cr)
            if highlight and cr then
                highlight.Parent = cr
                highlight.Enabled = default.highlight.enable
                
                esp(p, cr)
                toolEsp(p, cr)
                updateBoxESP(p)
                if default.flags.enable then
                    flagsEsp(p, cr)
                end
                if default.trail.enable then
                    createTrail(cr)
                end
            end
        end
        
        if p.Character then
            characterAdded(p.Character)
        end
        
        p.CharacterAdded:Connect(characterAdded)
    end
end

-- FOV circle (combat aim FOV; enable/radius from AsicVisuals)
do
    local sides, radius = 18, 160
    local out_line, in_line = {}, {}
    for i = 1, sides do
        local o = Drawing.new("Line")
        o.Thickness, o.Color, o.Transparency = 3, Color3.new(), 1
        out_line[i] = o
        local l = Drawing.new("Line")
        l.Thickness, l.Color, l.Transparency = 1, Color3.new(1, 1, 1), 1
        in_line[i] = l
    end
    rs.RenderStepped:Connect(function()
        local fovEnabled, fovRadius = getFOVConfig()
        radius = fovRadius or 160
        local center = (userInputService:GetMouseLocation() + guiService:GetGuiInset() - Vector2.new(0, 58))
        for i = 1, sides do
            local a1, a2 = math.rad(360 / sides * (i - 1)), math.rad(360 / sides * (i % sides))
            out_line[i].From = center + Vector2.new(math.cos(a1), math.sin(a1)) * radius
            out_line[i].To = center + Vector2.new(math.cos(a2), math.sin(a2)) * radius
            out_line[i].Visible = fovEnabled
            in_line[i].From = center + Vector2.new(math.cos(a1), math.sin(a1)) * radius
            in_line[i].To = center + Vector2.new(math.cos(a2), math.sin(a2)) * radius
            in_line[i].Visible = fovEnabled
        end
    end)
end

local watermark = Drawing.new("Text")
watermark.Text = "Rift.LoL"
watermark.Size = 16
watermark.Font = 2
watermark.Center = true
watermark.Outline = true
watermark.Color = Color3.new(1, 1, 1)
watermark.Visible = true
rs.RenderStepped:Connect(function()
    local mouse = userInputService:GetMouseLocation()
    watermark.Position = Vector2.new(mouse.X, mouse.Y + 20)
end)

for _, p in next, ps:GetPlayers() do
    if p ~= lp then
        playerAdded(p)
    end
end

ps.PlayerAdded:Connect(playerAdded)
ps.PlayerRemoving:Connect(playerRemoved)
rs.RenderStepped:Connect(drawSkeleton)
rs.RenderStepped:Connect(function()
    for player, _ in pairs(playerESP) do
        if player and player.Character then
            updateHighlightESP(player)
        end
    end
end)

return {
    SetBoxColor = function(color)
        default["2dbox"].color = color
    end,
    SetBoxEnabled = function(bool)
        default["2dbox"].enable = bool
    end,
    
    SetNameEnabled = function(bool)
        default.name.enable = bool
    end,
    SetNamePlacement = function(placement)
        default.name.placement = placement
    end,
    
    SetToolEnabled = function(bool)
        default.tool.enable = bool
    end,
    SetToolPlacement = function(placement)
        default.tool.placement = placement
    end,
    
    SetFlagsEnabled = function(bool)
        default.flags.enable = bool
    end,
    SetFlagsPlacement = function(placement)
        default.flags.placement = placement
    end,
    
    SetFOVEnabled = function(bool)
        default.fov.enable = bool
        if getgenv().AsicVisuals then getgenv().AsicVisuals.fov_enable = bool end
    end,
    SetFOVRadius = function(radius)
        if getgenv().AsicVisuals then getgenv().AsicVisuals.fov_radius = radius end
    end,
    GetFOVEnabled = function()
        local enab, _ = getFOVConfig()
        return enab
    end,
    GetFOVRadius = function()
        local _, r = getFOVConfig()
        return r or 160
    end,
    
    SetSkeletonEnabled = function(bool) 
        default.skeleton.enable = bool 
    end,
    SetSkeletonColor = function(color) 
        default.skeleton.color = color 
    end,
    SetSkeletonOutlineColor = function(color) 
        default.skeleton.outlineColor = color 
    end,
    SetSkeletonLineThickness = function(thickness) 
        default.skeleton.lineThickness = thickness 
    end,
    SetSkeletonOutlineThickness = function(thickness) 
        default.skeleton.outlineThickness = thickness 
    end,
    SetSkeletonOutlineEnabled = function(bool) 
        default.skeleton.outlineEnabled = bool 
    end,
    
    SetTrailEnabled = function(bool)
        default.trail.enable = bool
    end,
    SetTrailColor = function(color)
        default.trail.rgb = color
    end,
    SetTrailThickness = function(thickness)
        default.trail.thickness = thickness
    end,
    
    SetHighlightEnabled = function(bool)
        default.highlight.enable = bool
    end,
    SetHighlightColor = function(color)
        default.highlight.fillColor = color
    end,
    SetHighlightOutlineColor = function(color)
        default.highlight.outlineColor = color
    end,
    SetHighlightFillTransparency = function(transparency)
        default.highlight.fillTransparency = transparency
    end,
    SetHighlightOutlineTransparency = function(transparency)
        default.highlight.outlineTransparency = transparency
    end,

    SetESPEnabled = function(bool)
        for setting, value in pairs(default) do
            if type(value) == "table" and value.enable ~= nil then
                value.enable = bool
            end
        end
    end
}
