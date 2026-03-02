-- Aim assist: uses getgenv().AsicCombat and getgenv().AsicVisuals (FOV radius).
-- Hold the aim assist key to smooth-aim at the closest player inside the FOV circle.

local ps = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local cam = workspace.CurrentCamera
local lp = ps.LocalPlayer

local function getConfig()
    local g = getgenv()
    local combat = g.AsicCombat
    local visuals = g.AsicVisuals
    if not combat or not combat.aim_assist then return nil end
    return {
        key = combat.aim_assist_key,
        sticky = combat.sticky_aim,
        smoothing = tonumber(combat.smoothing) or 0.5,
        pred_y = tonumber(combat.prediction_y) or 1,
        pred_x = tonumber(combat.prediction_x) or 1,
        pred_z = tonumber(combat.prediction_z) or 1,
        fov_radius = (visuals and tonumber(visuals.fov_radius)) or 160,
        fov_enabled = not (visuals and visuals.fov_enable == false),
    }
end

local function isKeyHeld(key)
    if not key then return false end
    if key == Enum.UserInputType.MouseButton1 or key == Enum.UserInputType.MouseButton2 or key == Enum.UserInputType.MouseButton3 then
        return uis:IsMouseButtonPressed(key)
    end
    return uis:IsKeyDown(key)
end

local function getMouseScreen()
    return uis:GetMouseLocation() + guiService:GetGuiInset()
end

local function screenDistance(a, b)
    return (Vector2.new(a.X, a.Y) - Vector2.new(b.X, b.Y)).Magnitude
end

local function getClosestTargetInFOV(radius)
    local mouse = getMouseScreen()
    local bestPlayer, bestDist = nil, math.huge
    for _, player in ipairs(ps:GetPlayers()) do
        if player == lp or not player.Character then continue end
        local humanoid = player.Character:FindFirstChild("Humanoid")
        local head = player.Character:FindFirstChild("Head")
        if not humanoid or humanoid.Health <= 0 or not head then continue end
        local headScreen, onScreen = cam:WorldToViewportPoint(head.Position)
        if not onScreen then continue end
        local dist = screenDistance(mouse, Vector2.new(headScreen.X, headScreen.Y))
        if dist <= radius and dist < bestDist then
            bestDist = dist
            bestPlayer = player
        end
    end
    return bestPlayer, bestDist
end

local lastTarget = nil
local lastLook = nil

rs.RenderStepped:Connect(function()
    local cfg = getConfig()
    if not cfg or not cfg.fov_enabled or not isKeyHeld(cfg.key) then
        lastTarget = nil
        return
    end

    local radius = cfg.fov_radius
    local target = nil
    if cfg.sticky and lastTarget and lastTarget.Parent and lastTarget.Character then
        local h = lastTarget.Character:FindFirstChild("Humanoid")
        local head = lastTarget.Character:FindFirstChild("Head")
        if h and h.Health > 0 and head then
            local headScreen, onScreen = cam:WorldToViewportPoint(head.Position)
            if onScreen and screenDistance(getMouseScreen(), Vector2.new(headScreen.X, headScreen.Y)) <= radius then
                target = lastTarget
            end
        end
    end
    if not target then
        target, _ = getClosestTargetInFOV(radius)
        lastTarget = target
    end

    if not target or not target.Character then
        lastLook = nil
        return
    end

    local head = target.Character:FindFirstChild("Head")
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end

    local velocity = hrp.Velocity
    local predScale = 0.05
    local predictedPos = head.Position + Vector3.new(
        velocity.X * cfg.pred_x * predScale,
        velocity.Y * cfg.pred_y * predScale,
        velocity.Z * cfg.pred_z * predScale
    )

    local camPos = cam.CFrame.Position
    local toTarget = (predictedPos - camPos).Unit
    local smoothing = math.clamp(cfg.smoothing or 0, 0, 1)
    local currentLook = lastLook or cam.CFrame.LookVector
    local smoothedLook = currentLook:Lerp(toTarget, 1 - smoothing)
    lastLook = smoothedLook

    cam.CFrame = CFrame.lookAt(camPos, camPos + smoothedLook)
end)
