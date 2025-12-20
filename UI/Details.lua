local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.Details = {}

-- ... (Init function remains identical) ...
local parentFrame, nameText, countText, typeText, lastKillText, rankIcon, modelView, rankText
-- (Init code omitted for brevity as it didn't change, just paste your existing Init here if re-copying)

function NS.UI.Details.Init(mainFrame)
    -- ... (Paste previous Init content here) ...
    parentFrame = CreateFrame("Frame", nil, mainFrame)
    parentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 304, -22)
    parentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -305, 5)

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

    nameText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    nameText:SetPoint("TOP", headerFrame, "TOP", 0, -15)
    nameText:SetTextColor(1, 0.82, 0)

    typeText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeText:SetPoint("TOP", nameText, "BOTTOM", 0, -4)
    typeText:SetTextColor(0.7, 0.7, 0.7)

    countText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("TOP", typeText, "BOTTOM", 0, -6)
    countText:SetTextColor(1, 1, 1)

    lastKillText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastKillText:SetPoint("BOTTOM", headerFrame, "BOTTOM", 0, 8)
    lastKillText:SetTextColor(0.6, 0.6, 0.6)

    rankIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    rankIcon:SetSize(24, 24)
    rankIcon:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", -15, 10)
    rankText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("RIGHT", rankIcon, "LEFT", -5, 0)
    rankText:SetJustifyH("RIGHT")

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
    modelView.currentZoom = -2
    modelView:SetPosition(-2, 0, 0)

    modelView:SetScript("OnMouseDown", function(self, button)
        if button == "MiddleButton" then
            local isPaused = self:GetPaused()
            self:SetPaused(not isPaused)
        else
            self.drag = true
            self.sx = GetCursorPosition()
            self.sr = self:GetFacing() or 0
        end
    end)
    modelView:SetScript("OnMouseUp", function(self)
        self.drag = false
    end)
    modelView:SetScript("OnUpdate", function(self)
        if self.drag then
            local cx = GetCursorPosition();
            self:SetFacing(self.sr + (cx - self.sx) / 80)
        end
    end)
    modelView:EnableMouseWheel(true)
    modelView:SetScript("OnMouseWheel", function(self, d)
        self.currentZoom = math.max(-15, math.min(4, self.currentZoom + (d * 0.5)));
        self:SetPosition(self.currentZoom, 0, 0)
    end)
end

function NS.UI.Details.ShowMob(npcID)
    local data = MobCompendiumDB[npcID]
    if not data then
        return
    end

    nameText:SetText(data.name)

    if data.type then
        typeText:SetText(data.type)
        typeText:Show()
    else
        typeText:Hide()
    end

    countText:SetText("Killed: " .. data.kills)

    if data.lastTime and data.lastX and data.lastY then
        lastKillText:SetText(string.format("Loc: %.1f, %.1f  (%s)", data.lastX, data.lastY, data.lastTime))
        lastKillText:Show()
    else
        lastKillText:Hide()
    end

    local rKey = data.rank or "unknown"
    local rConfig = NS.RANK_CONFIG[rKey] or NS.RANK_CONFIG["unknown"]
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

    modelView.currentZoom = 0
    modelView:SetFacing(0)
    modelView:SetPosition(0, 0, 0)
    modelView:SetCreature(npcID)

end

function NS.UI.Details.Reset()
    if not nameText then
        return
    end
    nameText:SetText("")
    countText:SetText("")
    typeText:SetText("")
    lastKillText:SetText("")
    modelView:ClearModel()
end