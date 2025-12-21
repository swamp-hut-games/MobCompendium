local _, NS = ...

local BUTTON_RADIUS = 104

local button = CreateFrame("Button", "MobCompendiumMinimapButton", Minimap)
button:SetSize(32, 32)
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Visuals
local bg = button:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("CENTER")
bg:SetVertexColor(1, 1, 1, 0.6)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\MobCompendium\\icon.tga")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function UpdatePosition()
    local settings = MobCompendiumDB.settings.minimap
    local angle = math.rad(settings.angle)

    local x = math.cos(angle) * BUTTON_RADIUS
    local y = math.sin(angle) * BUTTON_RADIUS

    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Drag Logic
button:SetMovable(true)
button:RegisterForDrag("LeftButton")

button:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()

        cx, cy = cx / scale, cy / scale

        local dx = cx - mx
        local dy = cy - my

        local newAngle = math.deg(math.atan2(dy, dx))

        MobCompendiumDB.settings.minimap.angle = newAngle
        UpdatePosition()
    end)
end)

button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(self, buttonPressed)
    if buttonPressed == "LeftButton" then
        NS.ToggleUI()
    elseif buttonPressed == "RightButton" then
        if Settings and Settings.OpenToCategory and NS.SettingsCategory then
            Settings.OpenToCategory(NS.SettingsCategory:GetID())
        end
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Mob Compendium")
    GameTooltip:AddLine("Left Click: Toggle Window", 1, 1, 1)
    GameTooltip:AddLine("Right Click: Open Settings", 1, 1, 1)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not MobCompendiumDB.settings.minimap then
        MobCompendiumDB.settings.minimap = {
            hide = false,
            angle = 45
        }
    end
    UpdatePosition()
end)