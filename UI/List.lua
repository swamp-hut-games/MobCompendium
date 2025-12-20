local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.List = {}

-- Local References
local scrollChild, searchBox
local buttons = {}
local expandedZones = {}
local selectedNpcID = nil
local searchTimer = nil

local function ToggleZoneHeader(zoneName)
    local isExpanding = not expandedZones[zoneName]
    if IsAltKeyDown() then
        if isExpanding then
            for id, data in pairs(MobCompendiumDB) do
                if type(id) == "number" then
                    -- FIX: Only check actual mobs
                    local z = data.zone or "Unknown Zone"
                    expandedZones[z] = true
                end
            end
        else
            expandedZones = {}
        end
    else
        expandedZones[zoneName] = isExpanding
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
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self)
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

-- PUBLIC API: Refresh the scroll view
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
        -- FIX: CHECK IF ID IS A NUMBER
        -- This prevents the loop from trying to display "settings" or "windowPos" as mobs
        if type(id) == "number" then
            local z = data.zone or "Unknown Zone"
            local mobName = strlower(data.name or "")

            if not isSearching or string.find(mobName, searchText, 1, true) then
                if not zones[z] then
                    zones[z] = { mobs = {}, type = "none" }
                end

                local mType = data.instType or "none"
                if mType == "raid" then
                    zones[z].type = "raid"
                elseif mType == "party" and zones[z].type ~= "raid" then
                    zones[z].type = "party"
                elseif mType == "scenario" and zones[z].type == "none" then
                    zones[z].type = "scenario"
                end

                table.insert(zones[z].mobs, { id = id, name = data.name, rank = data.rank or "normal" })
            end
        end
    end

    -- 2. Sort & Build List
    local sortedZones = {}
    for zName, _ in pairs(zones) do
        table.insert(sortedZones, zName)
    end
    table.sort(sortedZones)

    for _, zName in ipairs(sortedZones) do
        local zoneData = zones[zName]
        local count = #zoneData.mobs
        local isExpanded = isSearching or expandedZones[zName]

        table.insert(displayList, {
            type = "HEADER", name = zName .. " (" .. count .. ")",
            rawZone = zName, instType = zoneData.type
        })

        if isExpanded then
            -- Safe sort: ensures we don't crash if a name is somehow nil
            table.sort(zoneData.mobs, function(a, b)
                return (a.name or "") < (b.name or "")
            end)

            for _, mob in ipairs(zoneData.mobs) do
                table.insert(displayList, { type = "MOB", name = mob.name, id = mob.id, rank = mob.rank })
            end
            table.insert(displayList, { type = "SPACER", height = 10 })
        end
    end

    -- 3. Render Buttons (Pooling)
    local heightAccumulator = 0
    for i, item in ipairs(displayList) do
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

        if item.type == "SPACER" then
            btn:Hide()
            heightAccumulator = heightAccumulator + item.height
        else
            btn:Show();
            btn:ClearAllPoints();
            btn:SetPoint("TOPLEFT", 0, -heightAccumulator);
            btn:SetWidth(260)

            if item.type == "HEADER" then
                local zConfig = NS.ZONE_ICONS[item.instType or "none"] or NS.ZONE_ICONS["none"]
                btn:SetHeight(26)
                btn.icon:SetPoint("LEFT", 5, 0);
                btn.icon:Show();
                btn.icon:SetTexture(zConfig.icon);
                btn.icon:SetVertexColor(unpack(zConfig.color))
                btn.text:SetPoint("LEFT", 25, 0);
                btn.text:SetFontObject("GameFontNormal");
                btn.text:SetText(item.name);
                btn.text:SetTextColor(1, 0.82, 0, 1)

                btn:EnableMouse(not isSearching)
                btn:SetScript("OnClick", function()
                    if not isSearching then
                        PlaySound(856);
                        ToggleZoneHeader(item.rawZone);
                        NS.UI.List.Update()
                    end
                end)
                if isSearching then
                    btn.highlight:Hide()
                else
                    btn.highlight:Show();
                    btn.highlight:SetColorTexture(1, 0.82, 0, 0.1)
                end
                heightAccumulator = heightAccumulator + 26
            else
                -- MOB ROW
                local rConfig = NS.RANK_CONFIG[item.rank or "normal"]
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
                btn.text:SetText(item.name)

                if item.id == selectedNpcID then
                    btn.text:SetTextColor(0.2, 0.82, 1, 1)
                    btn.highlight:SetColorTexture(0.2, 0.82, 1, 0.2)
                else
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
                end

                btn:SetScript("OnClick", function()
                    PlaySound(856)
                    selectedNpcID = item.id
                    NS.UI.List.Update()        -- Redraw list to show selection highlight
                    NS.UI.Details.ShowMob(item.id) -- Tell the other module to update
                end)
                btn:EnableMouse(true);
                btn.highlight:Show()
                heightAccumulator = heightAccumulator + 18
            end
        end
    end
    for i = #displayList + 1, #buttons do
        buttons[i]:Hide()
    end
    scrollChild:SetHeight(heightAccumulator)
end