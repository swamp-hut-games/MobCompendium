local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.List = {}

-- Local References
local scrollChild, searchBox
local buttons = {}
local expandedZones = {}
local selectedNpcID = nil
local searchTimer = nil

local function GetZoneKey(data)
    local z = data.zone or "Unknown Zone"
    local t = data.instType or "none"
    local d = data.diffName
    local mapID = data.mapID

    local suffix = ""

    if t == "party" then
        suffix = " (Dungeon)"
        if d and d ~= "" and d ~= "Normal" then
            suffix = " (" .. d .. " Dungeon)"
        end
    elseif t == "raid" then
        suffix = " (Raid)"
        if d and d ~= "" then
            suffix = " (" .. d .. " Raid)"
        end
    elseif t == "scenario" then
        suffix = " (Scenario)"
        if d and d ~= "" and d ~= "Normal" then
            suffix = " (" .. d .. " Scenario)"
        end
    elseif t == "pvp" or t == "arena" then
        suffix = " (PvP)"
    elseif t == "none" and mapID then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.parentMapID then
            local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
            if parentInfo and parentInfo.name then
                suffix = " (" .. parentInfo.name .. ")"
            end
        end
    end

    return z .. suffix, t
end

local function ToggleZoneHeader(zoneUniqueKey)
    local isExpanding = not expandedZones[zoneUniqueKey]
    if IsAltKeyDown() then
        if isExpanding then
            for id, data in pairs(MobCompendiumDB) do
                if type(id) == "number" then
                    local key, _ = GetZoneKey(data)
                    expandedZones[key] = true
                end
            end
        else
            expandedZones = {}
        end
    else
        expandedZones[zoneUniqueKey] = isExpanding
    end
end

function NS.UI.List.Init(mainFrame)
    local listBgFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    listBgFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -22)
    listBgFrame:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 4)
    listBgFrame:SetWidth(300)
    listBgFrame:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listBgFrame:SetBackdropColor(0.25, 0.25, 0.25, 1)

    searchBox = CreateFrame("EditBox", nil, listBgFrame, "InputBoxTemplate")
    searchBox:SetSize(280, 30)
    searchBox:SetPoint("TOP", listBgFrame, "TOP", 0, -12)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    
    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchBox.placeholder:SetPoint("LEFT", 4, 0)
    searchBox.placeholder:SetText("Search Mobs...")

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= "" then
            self.placeholder:Hide()
        else
            self.placeholder:Show()
        end
        
        if searchTimer then
            searchTimer:Cancel()
        end
        searchTimer = C_Timer.NewTimer(0.1, function()
            NS.UI.List.Update()
            searchTimer = nil
        end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listBgFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listBgFrame, "TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBgFrame, "BOTTOMRIGHT", -30, 10)

    scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(260, 500)
    scrollFrame:SetScrollChild(scrollChild)
end

function NS.UI.List.Reset()
    expandedZones = {}
    selectedNpcID = nil
    NS.UI.List.Update()
end

function NS.UI.List.Update()
    if not scrollChild or not scrollChild:IsVisible() then
        return
    end

    local displayList = {}
    local zones = {}

    -- 1. Filter Data
    local searchText = searchBox and strlower(searchBox:GetText() or "") or ""
    local isSearching = (searchText ~= "")

    for id, data in pairs(MobCompendiumDB) do
        if type(id) == "number" then
            local mobName = strlower(data.name or "")

            if not isSearching or string.find(mobName, searchText, 1, true) then

                local zoneKey, instType = GetZoneKey(data)

                if not zones[zoneKey] then
                    zones[zoneKey] = { mobs = {}, type = instType }
                end

                table.insert(zones[zoneKey].mobs, { id = id, name = data.name, rank = data.rank or "normal" })
            end
        end
    end

    -- 2. Sort & Build List
    local sortedZones = {}
    for zKey, _ in pairs(zones) do
        table.insert(sortedZones, zKey)
    end
    table.sort(sortedZones)

    for _, zKey in ipairs(sortedZones) do
        local zoneData = zones[zKey]
        local count = #zoneData.mobs
        local isExpanded = isSearching or expandedZones[zKey]

        table.insert(displayList, {
            type = "HEADER", name = zKey .. " (" .. count .. ")",
            rawZone = zKey, instType = zoneData.type
        })

        if isExpanded then
            table.sort(zoneData.mobs, function(a, b)
                return (a.name or "") < (b.name or "")
            end)

            for _, mob in ipairs(zoneData.mobs) do
                table.insert(displayList, { type = "MOB", name = mob.name, id = mob.id, rank = mob.rank })
            end
            table.insert(displayList, { type = "SPACER", height = 12 })
        end
    end

    -- 3. Render Buttons (Pooling)
    local heightAccumulator = 0
    local itemSpacing = 1

    for i, item in ipairs(displayList) do

        local thisItem = item
        local btn = buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(14, 14);
            btn.icon:SetPoint("LEFT", 5, 0)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetJustifyH("LEFT")
            btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            btn.highlight:SetAllPoints(btn);
            btn.highlight:SetColorTexture(1, 1, 1, 0.2)
            buttons[i] = btn
        end

        if thisItem.type == "SPACER" then
            btn:Hide()
            heightAccumulator = heightAccumulator + thisItem.height
        else
            btn:Show();
            btn:ClearAllPoints();
            btn:SetPoint("TOPLEFT", 0, -heightAccumulator);
            btn:SetWidth(260)

            if thisItem.type == "HEADER" then

                local zConfig = NS.ZONE_ICONS[thisItem.instType or "none"] or NS.ZONE_ICONS["none"]

                btn:SetHeight(26)
                btn.icon:SetPoint("LEFT", 5, 0);
                btn.icon:Show();
                btn.icon:SetTexture(zConfig.icon);
                btn.icon:SetVertexColor(unpack(zConfig.color))
                btn.text:SetPoint("LEFT", 25, 0);
                btn.text:SetFontObject("GameFontNormal");
                btn.text:SetText(thisItem.name);
                btn.text:SetTextColor(1, 0.82, 0, 1)

                btn:EnableMouse(not isSearching)
                btn:SetScript("OnClick", function()
                    if not isSearching then
                        PlaySound(856);
                        ToggleZoneHeader(thisItem.rawZone);
                        NS.UI.List.Update()
                    end
                end)
                if isSearching then
                    btn.highlight:Hide()
                else
                    btn.highlight:Show();
                    btn.highlight:SetColorTexture(1, 0.82, 0, 0.1)
                end

                heightAccumulator = heightAccumulator + 26 + itemSpacing
            else
                -- MOB ROW
                local rConfig = NS.RANK_CONFIG[thisItem.rank or "normal"]
                btn:SetHeight(18)
                btn.icon:SetPoint("LEFT", 20, 0)
                if rConfig and rConfig.icon then
                    btn.icon:Show();
                    btn.icon:SetTexture(rConfig.icon);
                    btn.icon:SetVertexColor(unpack(rConfig.color or { 1, 1, 1 }))
                    if rConfig.coords then
                        btn.icon:SetTexCoord(unpack(rConfig.coords))
                    end
                else
                    btn.icon:Hide()
                end

                btn.text:SetPoint("LEFT", 40, 0);
                btn.text:SetText(thisItem.name)

                if thisItem.id == selectedNpcID then
                    btn.text:SetTextColor(0.2, 0.82, 1, 1)
                    btn.highlight:SetColorTexture(0.2, 0.82, 1, 0.2)
                else
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
                end

                btn:SetScript("OnClick", function()
                    PlaySound(856)
                    selectedNpcID = thisItem.id
                    NS.UI.List.Update()
                    NS.UI.Details.ShowMob(thisItem.id)

                    if NS.UI.RightColumn then
                        NS.UI.RightColumn.Update(thisItem.id)
                    end
                end)

                btn:EnableMouse(true);
                btn.highlight:Show()

                heightAccumulator = heightAccumulator + 18 + itemSpacing
            end
        end
    end
    for i = #displayList + 1, #buttons do
        buttons[i]:Hide()
    end
    scrollChild:SetHeight(heightAccumulator)
end