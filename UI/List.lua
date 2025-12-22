local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.List = {}

-- Local References
local scrollChild, searchBox
local buttons = {}

-- Expansion State
local expandedParents = {}   -- "Khaz Algar" = true
local expandedSubZones = {}  -- "Khaz Algar::The Ringing Deeps" = true
local selectedNpcID = nil
local searchTimer = nil

-- Helper: Create a unique key for subzones to prevent collisions
local function GetSubZoneKey(parent, zone)
    return parent .. "::" .. zone
end

local function ToggleParent(parentKey)
    if IsAltKeyDown() then
        local isExpanding = not expandedParents[parentKey]
        expandedParents[parentKey] = isExpanding
    else
        expandedParents[parentKey] = not expandedParents[parentKey]
    end
end

local function ToggleSubZone(uniqueKey)
    expandedSubZones[uniqueKey] = not expandedSubZones[uniqueKey]
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
    expandedParents = {}
    expandedSubZones = {}
    selectedNpcID = nil
    NS.UI.List.Update()
end

function NS.UI.List.Update()
    if not scrollChild or not scrollChild:IsVisible() then
        return
    end

    local displayList = {}
    local hierarchy = {}

    -- 1. Filter & Group Data
    local searchText = searchBox and strlower(searchBox:GetText() or "") or ""
    local isSearching = (searchText ~= "")

    for id, mobData in pairs(MobCompendiumDB) do
        if type(id) == "number" then
            local mobName = strlower(mobData.name or "")

            if not isSearching or string.find(mobName, searchText, 1, true) then

                -- NEW: Iterate over 'encounters' instead of root properties
                if mobData.encounters then
                    for mapID, encounter in pairs(mobData.encounters) do

                        local pKey = encounter.parentMap or "Uncategorized"
                        local zKey = encounter.zoneName or "Unknown Zone"

                        -- Append Difficulty if present
                        if encounter.instType and encounter.instType ~= "none" and encounter.diffName and encounter.diffName ~= "" then
                            zKey = zKey .. " (" .. encounter.diffName .. ")"
                        end

                        if not hierarchy[pKey] then
                            hierarchy[pKey] = { zones = {}, type = (encounter.instType or "none") }
                        end

                        if not hierarchy[pKey].zones[zKey] then
                            hierarchy[pKey].zones[zKey] = { mobs = {} }
                        end

                        -- Add Mob to this Zone's list
                        -- We use encounter.rank here because a mob might be Elite in one map but Normal in another
                        table.insert(hierarchy[pKey].zones[zKey].mobs, {
                            id = id,
                            name = mobData.name,
                            rank = encounter.rank or "normal",
                            -- Optional: Pass mapID if you want Details pane to focus this specific map later
                            mapID = mapID
                        })
                    end
                end
            end
        end
    end

    -- 2. Sort & Flatten for Display
    local sortedParents = {}
    for pKey, _ in pairs(hierarchy) do
        table.insert(sortedParents, pKey)
    end
    table.sort(sortedParents)

    for _, pKey in ipairs(sortedParents) do
        local parentData = hierarchy[pKey]

        local parentTotal = 0
        local sortedZones = {}
        for zKey, zData in pairs(parentData.zones) do
            parentTotal = parentTotal + #zData.mobs
            table.insert(sortedZones, zKey)
        end
        table.sort(sortedZones)

        table.insert(displayList, {
            type = "PARENT",
            name = pKey .. " (" .. parentTotal .. ")",
            key = pKey,
            instType = parentData.type
        })

        if isSearching or expandedParents[pKey] then

            for _, zKey in ipairs(sortedZones) do
                local zData = parentData.zones[zKey]
                local uniqueZKey = GetSubZoneKey(pKey, zKey)
                local count = #zData.mobs

                table.insert(displayList, {
                    type = "ZONE",
                    name = zKey .. " (" .. count .. ")",
                    key = uniqueZKey
                })

                if isSearching or expandedSubZones[uniqueZKey] then

                    table.sort(zData.mobs, function(a, b)
                        return (a.name or "") < (b.name or "")
                    end)

                    for _, mob in ipairs(zData.mobs) do
                        table.insert(displayList, {
                            type = "MOB",
                            name = mob.name,
                            id = mob.id,
                            rank = mob.rank,
                            mapID = mob.mapID
                        })
                    end
                    table.insert(displayList, { type = "SPACER", height = 8 })
                end
            end
        end
        table.insert(displayList, { type = "SPACER", height = 4 })
    end

    -- 3. Render (Button Pooling)
    local heightAccumulator = 0
    local itemSpacing = 1

    for i, item in ipairs(displayList) do
        local btn = buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(14, 14)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetJustifyH("LEFT")
            btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
            btn.highlight:SetAllPoints(btn)
            btn.highlight:SetColorTexture(1, 1, 1, 0.1)
            buttons[i] = btn
        end

        btn:ClearAllPoints()

        if item.type == "SPACER" then
            btn:Hide()
            heightAccumulator = heightAccumulator + item.height
        else
            btn:Show()
            btn:SetPoint("TOPLEFT", 0, -heightAccumulator)
            btn:SetWidth(260)

            if item.type == "PARENT" then
                local zConfig = NS.ZONE_ICONS[item.instType or "none"] or NS.ZONE_ICONS["none"]

                btn:SetHeight(24)
                btn.icon:Show()
                btn.icon:SetPoint("LEFT", 5, 0)
                btn.icon:SetTexture(zConfig.icon)
                btn.icon:SetVertexColor(unpack(zConfig.color))

                btn.text:SetPoint("LEFT", 25, 0)
                btn.text:SetFontObject("GameFontNormal")
                btn.text:SetText(item.name)
                btn.text:SetTextColor(1.0, 0.6, 0.0, 1)

                btn:SetScript("OnClick", function()
                    if not isSearching then
                        PlaySound(856)
                        ToggleParent(item.key)
                        NS.UI.List.Update()
                    end
                end)

            elseif item.type == "ZONE" then
                btn:SetHeight(22)
                btn.icon:Hide()

                btn.text:SetPoint("LEFT", 20, 0)
                btn.text:SetFontObject("GameFontNormal")
                btn.text:SetText(item.name)
                btn.text:SetTextColor(1.0, 0.82, 0.0, 1) -- Yellow/Gold

                btn:SetScript("OnClick", function()
                    if not isSearching then
                        PlaySound(856)
                        ToggleSubZone(item.key)
                        NS.UI.List.Update()
                    end
                end)

            elseif item.type == "MOB" then
                local rConfig = NS.RANK_CONFIG[item.rank or "normal"]
                btn:SetHeight(20)

                btn.icon:Show()
                btn.icon:SetPoint("LEFT", 30, 0)
                if rConfig and rConfig.icon then
                    btn.icon:SetTexture(rConfig.icon)
                    if rConfig.coords then
                        btn.icon:SetTexCoord(unpack(rConfig.coords))
                    end
                end

                btn.text:SetPoint("LEFT", 50, 0)
                btn.text:SetFontObject("GameFontHighlightSmall")
                btn.text:SetText(item.name)

                if item.id == selectedNpcID then
                    btn.text:SetTextColor(0.2, 1, 1, 1)
                    btn.highlight:SetColorTexture(0.2, 1, 1, 0.1)
                else
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn.highlight:SetColorTexture(1, 1, 1, 0.1)
                end

                btn:SetScript("OnClick", function()
                    PlaySound(856)
                    selectedNpcID = item.id
                    NS.UI.List.Update()

                    -- NOTE: You will need to update Details.ShowMob to handle mapID if you want specific zone info
                    if NS.UI.Details and NS.UI.Details.ShowMob then
                        NS.UI.Details.ShowMob(item.id, item.mapID)
                    end
                    if NS.UI.RightColumn then
                        NS.UI.RightColumn.Update(item.id)
                    end
                end)
            end

            heightAccumulator = heightAccumulator + (item.type == "PARENT" and 24 or (item.type == "ZONE" and 22 or 18)) + itemSpacing
        end
    end

    for i = #displayList + 1, #buttons do
        buttons[i]:Hide()
    end
    scrollChild:SetHeight(heightAccumulator)
end