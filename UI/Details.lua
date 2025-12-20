local _, NS = ...

-- Namespace for UI components
NS.UI = NS.UI or {}
NS.UI.Details = {}

-- Local References
local parentFrame
local nameText, countText, rankText, lastKillText
local rankIcon, modelView

function NS.UI.Details.Init(mainFrame)
    parentFrame = CreateFrame("Frame", nil, mainFrame)
    parentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 304, -22)
    parentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -5, 5)

    -- 1. HEADER AREA
    local headerFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    headerFrame:SetHeight(120)
    headerFrame:SetPoint("TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", 0, 0)
    headerFrame:SetBackdrop({
        bgFile = "Interface\\Collections\\CollectionsBackgroundTile",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    headerFrame:SetBackdropColor(1, 1, 1, 1)

    -- Text Elements
    nameText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    nameText:SetPoint("TOP", headerFrame, "TOP", 0, -15)

    countText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countText:SetScale(1.2)
    countText:SetPoint("TOP", nameText, "BOTTOM", 0, -8)

    lastKillText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastKillText:SetPoint("TOP", countText, "BOTTOM", 0, -5)
    lastKillText:SetTextColor(0.7, 0.7, 0.7)

    rankIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    rankIcon:SetSize(24, 24)
    rankIcon:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", -15, 10)

    rankText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("RIGHT", rankIcon, "LEFT", -5, 0)
    rankText:SetJustifyH("RIGHT")

    -- 2. MODEL AREA
    local modelFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    modelFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    modelFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    modelFrame:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 6 })
    modelFrame:SetBackdropColor(0.55, 0.55, 0.55, 1)

    local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Spellbook\\Spellbook-Page-1")
    bg:SetPoint("TOPLEFT", -70, 0)
    bg:SetPoint("BOTTOMRIGHT", 50, -50)
    bg:SetVertexColor(0.45, 0.45, 0.45, 1)
    modelFrame:SetClipsChildren(true)

    modelView = CreateFrame("PlayerModel", nil, modelFrame)
    modelView:SetPoint("TOPLEFT", 4, -4)
    modelView:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Model Interaction
    modelView.currentZoom = -2
    modelView:SetPosition(-2, 0, 0)

    modelView:SetScript("OnMouseDown", function(self)
        self.drag = true
        self.sx = GetCursorPosition()
        self.sr = self:GetFacing() or 0
    end)

    modelView:SetScript("OnMouseUp", function(self)
        self.drag = false
    end)

    modelView:SetScript("OnUpdate", function(self)
        if self.drag then
            local cx = GetCursorPosition()
            self:SetFacing(self.sr + (cx - self.sx) / 80)
        end
    end)

    modelView:EnableMouseWheel(true)
    modelView:SetScript("OnMouseWheel", function(self, d)
        self.currentZoom = math.max(-15, math.min(4, self.currentZoom + (d * 0.5)))
        self:SetPosition(self.currentZoom, 0, 0)
    end)
end

-- PUBLIC API: Show a specific mob
function NS.UI.Details.ShowMob(npcID)
    local data = MobCompendiumDB[npcID]
    if not data then
        return
    end

    -- Text Updates
    nameText:SetText(data.name)
    countText:SetText("Killed: " .. data.kills)

    if data.lastTime and data.lastX and data.lastY then
        lastKillText:SetText(string.format("Last Kill: %.1f, %.1f  |cffaaaaaa(%s)|r", data.lastX, data.lastY, data.lastTime))
        lastKillText:Show()
    else
        lastKillText:Hide()
    end

    -- Rank Updates
    local rKey = data.rank or "normal"
    local rConfig = NS.RANK_CONFIG[rKey] or NS.RANK_CONFIG["normal"]
    rankText:SetText(rConfig.text)

    if rConfig.icon then
        rankIcon:Show()
        rankIcon:SetTexture(rConfig.icon)
        if rConfig.coords then
            rankIcon:SetTexCoord(unpack(rConfig.coords))
        end
        rankIcon:SetVertexColor(unpack(rConfig.color or { 1, 1, 1 }))
    else
        rankIcon:Hide()
    end
    
    modelView:SetCreature(npcID)
    modelView.currentZoom = 0
    modelView:SetFacing(0)
    modelView:SetPosition(0, 0, 0)
end

function NS.UI.Details.Reset()
    nameText:SetText("")
    countText:SetText("")
    lastKillText:SetText("")
    modelView:ClearModel()
end