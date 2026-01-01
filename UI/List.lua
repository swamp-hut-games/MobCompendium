local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.List = {}

-- Local References
local scrollChild, searchBox
local buttons = {}

-- Expansion State
local expandedParents = {}
local expandedSubZones = {}

-- State Helpers
local visibleParentKeys = {}   -- List of all current parent keys (for Alt+Click)
local parentToSubZoneKeys = {} -- Map of ParentKey -> List of SubZoneKeys (for Shift+Click)
local isInitialized = false
local selectedNpcID = nil
local searchTimer = nil
local searchMenu = nil

-- Create a unique key for subzones to prevent collisions
local function GetSubZoneKey(parent, zone)
    return parent .. "::" .. zone
end

local function MatchesFilter(mobData, searchText, filters)
    -- If search is empty, show everything
    if searchText == "" then
        return true
    end

    -- If NO filters are selected, return false
    if not filters.mobs and not filters.zones and not filters.loot and not filters.spells then
        return false
    end

    if filters.mobs then
        local name = strlower(mobData.name or "")
        if string.find(name, searchText, 1, true) then
            return true
        end
    end

    if filters.zones and mobData.encounters then
        for _, enc in pairs(mobData.encounters) do
            local pMap = strlower(enc.parentMap or "")
            local zName = strlower(enc.zoneName or "")
            if string.find(pMap, searchText, 1, true) or string.find(zName, searchText, 1, true) then
                return true
            end
        end
    end

    if filters.spells and mobData.spells then
        for spellID, _ in pairs(mobData.spells) do
            local info = C_Spell.GetSpellInfo(spellID)
            if info and info.name then
                if string.find(strlower(info.name), searchText, 1, true) then
                    return true
                end
            end
        end
    end

    if filters.loot and mobData.encounters then
        for _, enc in pairs(mobData.encounters) do
            if enc.drops then
                for itemID, _ in pairs(enc.drops) do

                    -- Might cause hiccups if searching for items not cached after relog
                    local itemName = GetItemInfo(itemID)
                    if itemName then
                        if string.find(strlower(itemName), searchText, 1, true) then
                            return true
                        end
                    end

                end
            end
        end
    end

    return false
end

local function ToggleParent(parentKey)
    local parentIsOpen = expandedParents[parentKey]

    if IsAltKeyDown() then
        local targetGlobalState = not parentIsOpen
        for _, pKey in ipairs(visibleParentKeys) do
            expandedParents[pKey] = targetGlobalState
            if parentToSubZoneKeys[pKey] then
                for _, sKey in ipairs(parentToSubZoneKeys[pKey]) do
                    expandedSubZones[sKey] = targetGlobalState
                end
            end
        end
    elseif IsShiftKeyDown() then
        expandedParents[parentKey] = true
        local subKeys = parentToSubZoneKeys[parentKey]
        if subKeys and #subKeys > 0 then
            local anyChildOpen = false
            for _, sKey in ipairs(subKeys) do
                if expandedSubZones[sKey] then
                    anyChildOpen = true
                    break
                end
            end
            local targetChildState = not anyChildOpen
            for _, sKey in ipairs(subKeys) do
                expandedSubZones[sKey] = targetChildState
            end
        end
    else
        expandedParents[parentKey] = not parentIsOpen
    end
end

local function ToggleSubZone(uniqueKey)
    expandedSubZones[uniqueKey] = not expandedSubZones[uniqueKey]
end

function NS.UI.List.Init(mainFrame)
    if MobCompendiumDB and not MobCompendiumDB.searchFilter then
        MobCompendiumDB.searchFilter = {
            mobs = true,
            zones = true,
            loot = true,
            spells = true
        }
    end

    local listBgFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    listBgFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -22)
    listBgFrame:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 45)
    listBgFrame:SetWidth(300)
    listBgFrame:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listBgFrame:SetBackdropColor(0.25, 0.25, 0.25, 1)

    searchBox = CreateFrame("EditBox", nil, listBgFrame, "InputBoxTemplate")
    searchBox:SetSize(255, 30)
    searchBox:SetPoint("TOPLEFT", listBgFrame, "TOPLEFT", 10, -12)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")

    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchBox.placeholder:SetPoint("LEFT", 4, 0)
    searchBox.placeholder:SetText("Search...")

    local clearBtn = CreateFrame("Button", nil, searchBox)
    clearBtn:SetSize(17, 17)
    clearBtn:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
    clearBtn:Hide()

    clearBtn.texture = clearBtn:CreateTexture(nil, "ARTWORK")
    clearBtn.texture:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clearBtn.texture:SetAlpha(0.5)
    clearBtn.texture:SetAllPoints()

    clearBtn:SetScript("OnEnter", function(self)
        self.texture:SetAlpha(1.0)
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self.texture:SetAlpha(0.5)
    end)

    clearBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if searchMenu then
            searchMenu:Hide()
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()

        if text ~= "" then
            self.placeholder:Hide()
            clearBtn:Show()
        else
            self.placeholder:Show()
            clearBtn:Hide()
        end

        if searchTimer then
            searchTimer:Cancel()
        end
        searchTimer = C_Timer.NewTimer(0.1, function()
            NS.UI.List.Update()
            searchTimer = nil
        end)
    end)

    local settingsBtn = CreateFrame("Button", nil, listBgFrame)
    settingsBtn:SetSize(20, 20)
    settingsBtn:SetPoint("LEFT", searchBox, "RIGHT", 4, -1)
    settingsBtn.icon = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsBtn.icon:SetAllPoints()
    settingsBtn.icon:SetTexture("Interface\\WorldMap\\Gear_64")
    settingsBtn.icon:SetTexCoord(0, 0.5, 0, 0.5)

    searchMenu = CreateFrame("Frame", nil, listBgFrame, "BackdropTemplate")
    searchMenu:SetSize(120, 130)
    searchMenu:SetPoint("TOPRIGHT", settingsBtn, "BOTTOMRIGHT", 100, -5)
    searchMenu:SetFrameStrata("DIALOG")
    searchMenu:Hide()

    searchMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    local function CreateSearchOption(label, key, relativeTo)
        local cb = CreateFrame("CheckButton", nil, searchMenu, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -2)
        cb.text:SetText(label)
        cb.text:SetFontObject("GameFontNormalSmall")

        if MobCompendiumDB and MobCompendiumDB.searchFilter then
            cb:SetChecked(MobCompendiumDB.searchFilter[key])
        else
            cb:SetChecked(true)
        end

        cb:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if MobCompendiumDB and MobCompendiumDB.searchFilter then
                MobCompendiumDB.searchFilter[key] = isChecked
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                if searchBox:GetText() ~= "" then
                    NS.UI.List.Update()
                end
            end
        end)
        return cb
    end

    local title = searchMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Search for")

    local cbMobs = CreateSearchOption("Mobs", "mobs", title)
    cbMobs:SetPoint("TOPLEFT", 10, -25)
    local cbZones = CreateSearchOption("Zones", "zones", cbMobs)
    local cbLoot = CreateSearchOption("Loot", "loot", cbZones)
    local cbSpells = CreateSearchOption("Spells", "spells", cbLoot)

    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Search Settings")
        GameTooltip:Show()
        self.icon:SetVertexColor(1, 0.82, 0)
    end)

    settingsBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.icon:SetVertexColor(1, 1, 1)
    end)

    settingsBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if searchMenu:IsShown() then
            searchMenu:Hide()
        else
            searchMenu:Show()
        end
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
    isInitialized = false
    NS.UI.List.Update()
end

function NS.UI.List.Update()
    if not scrollChild or not scrollChild:IsVisible() then
        return
    end

    visibleParentKeys = {}
    parentToSubZoneKeys = {}

    local displayList = {}
    local hierarchy = {}

    local searchText = searchBox and strlower(searchBox:GetText() or "") or ""
    local isSearching = (searchText ~= "")

    local filters = MobCompendiumDB.searchFilter or { mobs = true, zones = true, loot = true, spells = true }

    local rankFilters = nil
    if NS.UI.FilterBar and NS.UI.FilterBar.GetState then
        rankFilters = NS.UI.FilterBar.GetState()
    end

    for id, mobData in pairs(MobCompendiumDB) do
        if type(id) == "number" then

            if MatchesFilter(mobData, searchText, filters) then

                if mobData.encounters then
                    for mapID, encounter in pairs(mobData.encounters) do

                        local eRank = encounter.rank or "unknown"
                        -- Safety check if rank key doesn't exist in our known list
                        if not NS.RANK_CONFIG[eRank] then
                            eRank = "unknown"
                        end

                        local isRankAllowed = true
                        if rankFilters and not rankFilters[eRank] then
                            isRankAllowed = false
                        end

                        if isRankAllowed then
                            local pKey = encounter.parentMap or "Uncategorized"

                            if pKey ~= "Uncategorized" then

                                local zKey = encounter.zoneName or "Unknown Zone"

                                if encounter.instType and encounter.instType ~= "none" and encounter.diffName and encounter.diffName ~= "" then
                                    pKey = pKey .. " [" .. encounter.diffName .. "]"
                                end

                                if not hierarchy[pKey] then
                                    hierarchy[pKey] = { zones = {}, type = (encounter.instType or "none") }
                                end

                                if not hierarchy[pKey].zones[zKey] then
                                    hierarchy[pKey].zones[zKey] = { mobs = {}, seen = {} }
                                end

                                if not hierarchy[pKey].zones[zKey].seen[id] then
                                    table.insert(hierarchy[pKey].zones[zKey].mobs, {
                                        id = id,
                                        name = mobData.name,
                                        rank = encounter.rank or "normal",
                                        groupParent = pKey,
                                        groupZone = zKey
                                    })
                                    hierarchy[pKey].zones[zKey].seen[id] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local sortedParents = {}
    for pKey, _ in pairs(hierarchy) do
        table.insert(sortedParents, pKey)
    end
    table.sort(sortedParents)

    visibleParentKeys = sortedParents

    if not isInitialized then
        local currentZoneName = nil
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo then
                currentZoneName = mapInfo.name
            end
        end

        for _, pKey in ipairs(sortedParents) do
            expandedParents[pKey] = true
            if hierarchy[pKey] and hierarchy[pKey].zones then
                for zKey, _ in pairs(hierarchy[pKey].zones) do
                    if currentZoneName and string.find(zKey, currentZoneName, 1, true) then
                        local uniqueZKey = GetSubZoneKey(pKey, zKey)
                        expandedSubZones[uniqueZKey] = true
                    end
                end
            end
        end
        isInitialized = true
    end

    for _, pKey in ipairs(sortedParents) do
        local parentData = hierarchy[pKey]

        local parentTotal = 0
        local sortedZones = {}

        parentToSubZoneKeys[pKey] = {}

        for zKey, zData in pairs(parentData.zones) do
            parentTotal = parentTotal + #zData.mobs
            table.insert(sortedZones, zKey)
            table.insert(parentToSubZoneKeys[pKey], GetSubZoneKey(pKey, zKey))
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
                            groupParent = mob.groupParent,
                            groupZone = mob.groupZone
                        })
                    end
                    table.insert(displayList, { type = "SPACER", height = 8 })
                end
            end
        end
        table.insert(displayList, { type = "SPACER", height = 4 })
    end

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
                local iconSize = zConfig.size or 14

                btn:SetHeight(24)
                btn.icon:SetSize(iconSize, iconSize)
                btn.icon:Show()
                btn.icon:ClearAllPoints()
                btn.icon:SetPoint("CENTER", btn, "LEFT", 12, 0)
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
                btn.text:SetTextColor(1.0, 0.82, 0.0, 1)

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
                btn.icon:SetSize(14, 14)
                btn.icon:Show()
                btn.icon:ClearAllPoints()
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

                    if NS.UI.Details and NS.UI.Details.ShowMob then
                        NS.UI.Details.ShowMob(item.id, item.groupParent, item.groupZone)
                    end
                    if NS.UI.RightColumn and NS.UI.RightColumn.Update then
                        NS.UI.RightColumn.Update(item.id, item.groupParent, item.groupZone)
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