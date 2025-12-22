local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.Details = {}

local parentFrame, nameText, countText, typeText, lastKillText, rankIcon, modelView, rankText

function NS.UI.Details.Init(mainFrame)

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

    -- Initialize state variables on the frame
    modelView.currentZoom = -2
    modelView.panX = 0
    modelView.panY = 0
    modelView:SetPosition(modelView.currentZoom, modelView.panX, modelView.panY)

    modelView:SetScript("OnMouseDown", function(self, button)
        -- Capture raw cursor position for delta calculations
        local cx, cy = GetCursorPosition()

        if button == "LeftButton" then
            self.isRotating = true
            self.startX = cx
            self.startRotation = self:GetFacing() or 0

        elseif button == "RightButton" then
            self.isPanning = true
            self.startX = cx
            self.startY = cy
            self.startPanX = self.panX
            self.startPanY = self.panY

        elseif button == "MiddleButton" then
            local isPaused = self:GetPaused()
            self:SetPaused(not isPaused)
        end
    end)

    modelView:SetScript("OnMouseUp", function(self)
        self.isRotating = false
        self.isPanning = false
    end)

    modelView:SetScript("OnUpdate", function(self)
        local cx, cy = GetCursorPosition()

        if self.isRotating then
            self:SetFacing(self.startRotation + (cx - self.startX) / 80)

        elseif self.isPanning then

            local baseSensitivity = 80
            local zoomScale = math.max(0.1, (10 - self.currentZoom) / 10)

            local deltaX = ((cx - self.startX) / baseSensitivity) * zoomScale
            local deltaY = ((cy - self.startY) / baseSensitivity) * zoomScale

            local newX = self.startPanX + deltaX
            local newY = self.startPanY + deltaY

            local clampLimit = 8.0
            newX = math.max(-clampLimit, math.min(clampLimit, newX))
            newY = math.max(-clampLimit, math.min(clampLimit, newY))

            self.panX = newX
            self.panY = newY
            self:SetPosition(self.currentZoom, newX, newY)
        end
    end)

    modelView:EnableMouseWheel(true)
    modelView:SetScript("OnMouseWheel", function(self, d)
        self.currentZoom = math.max(-15, math.min(4, self.currentZoom + (d * 0.5)))
        self:SetPosition(self.currentZoom, self.panX, self.panY)
    end)
end

function NS.UI.Details.ShowMob(npcID, mapID)
    local data = MobCompendiumDB[npcID]
    if not data then
        return
    end

    nameText:SetText(data.name)

    local totalKills = 0
    local specificKills = 0
    local displayRank = "unknown"
    local displayType = nil

    local lastSeenEntry = nil
    local latestTimeStr = ""

    if data.encounters then
        for mID, encounter in pairs(data.encounters) do
            totalKills = totalKills + (encounter.kills or 0)

            if mapID and mapID == mID then
                specificKills = encounter.kills
            end

            if (mapID and mapID == mID) or (not mapID and displayRank == "unknown") then
                if encounter.rank then
                    displayRank = encounter.rank
                end
                if encounter.type then
                    displayType = encounter.type
                end
            end

            if encounter.lastTime and encounter.lastTime > latestTimeStr then
                latestTimeStr = encounter.lastTime
                lastSeenEntry = encounter
            end
        end
    end

    if displayType then
        typeText:SetText(displayType)
        typeText:Show()
    else
        typeText:Hide()
    end

    if mapID and specificKills > 0 then
        countText:SetText("Killed: " .. specificKills)
    else
        countText:SetText("Killed: " .. totalKills)
    end

    local locData = lastSeenEntry
    if mapID and data.encounters and data.encounters[mapID] then
        locData = data.encounters[mapID]
    end

    if locData then
        local timeStr = locData.lastTime or "?"
        if locData.lastX and locData.lastY then
            lastKillText:SetText(string.format("Loc: %.1f, %.1f (%s)", locData.lastX, locData.lastY, timeStr))
            lastKillText:Show()
        else
            lastKillText:SetText("Last Seen: " .. timeStr)
            lastKillText:Show()
        end
    else
        lastKillText:Hide()
    end

    local rKey = displayRank or "unknown"
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
    modelView.panX = 0
    modelView.panY = 0
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