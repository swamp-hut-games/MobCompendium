-- =========================================================================
-- 1. SETUP & VARIABLES
-- =========================================================================
local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- UI Elements
local mainFrame = nil
local modelView = nil
local nameText = nil
local countText = nil
local rankText = nil
local rankIcon = nil
local lastKillText = nil
local scrollChild = nil
local searchBox = nil
local buttons = {}

-- Forward Declaration
local UpdateList

-- STATE: Track which zones are open (Default: All closed/nil)
local expandedZones = {}
local selectedNpcID = nil

-- CONFIG: Global Icon Definitions
local RANK_CONFIG = {
    boss = {
        text = "Boss",
        icon = "Interface\\Icons\\inv_misc_bone_humanskull_02",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    rareelite = {
        text = "Rare Elite",
        icon = "Interface\\Icons\\inv_misc_head_dragon_black",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    elite = {
        text = "Elite",
        icon = "Interface\\Icons\\inv_misc_head_dragon_bronze",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    rare = {
        text = "Rare",
        icon = "Interface\\Icons\\inv_misc_head_dragon_blue",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    minion = {
        text = "Minion",
        icon = "Interface\\Icons\\inv_babyfaeriedragon",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    critter = {
        text = "Critter",
        icon = "Interface\\Icons\\INV_Misc_Rabbit_2",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    normal = {
        text = "Normal",
        icon = "Interface\\Icons\\Achievement_character_human_male",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    }
}

-- NEW: Zone Icon Definitions
local ZONE_ICONS = {
    raid = {
        icon = "Interface\\Icons\\LevelUpIcon-LFR", -- Raid Shield Icon
        color = { 1, 1, 1 }
    },
    party = {
        icon = "Interface\\Icons\\LevelUpIcon-LFD", -- Dungeon Eye Icon
        color = { 1, 1, 1 }
    },
    scenario = {
        icon = "Interface\\Icons\\Icon_Scenarios",
        color = { 1, 1, 1 }
    },
    none = {
        icon = "Interface\\Icons\\INV_Misc_Map02", -- Standard Map
        color = { 1, 1, 1 }
    },
    pvp = {
        icon = "Interface\\Icons\\Faction_Alliance_Vanguard",
        color = { 1, 0, 0 }
    }
}

local function CreateMobCompendiumUI()
    if mainFrame then
        mainFrame:Show();
        return
    end

    -- 1. MAIN WINDOW
    mainFrame = CreateFrame("Frame", "MobCompendiumMainWindow", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(900, 600)
    if MobCompendiumDB and MobCompendiumDB.windowPos then
        local pos = MobCompendiumDB.windowPos
        mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

    mainFrame:SetScript("OnShow", function()
        PlaySound(862)
    end)
    mainFrame:SetScript("OnHide", function()
        PlaySound(863)
    end)
    tinsert(UISpecialFrames, "MobCompendiumMainWindow")

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY")
    mainFrame.title:SetFontObject("GameFontHighlight")
    mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0)
    mainFrame.title:SetText("Mob Compendium")

    -- =====================================================================
    -- LEFT COLUMN CONTAINER (The "Backdrop" Approach)
    -- =====================================================================
    -- 1. Create Frame with "BackdropTemplate"
    local listBgFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")

    listBgFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -22)
    listBgFrame:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 4)
    listBgFrame:SetWidth(300)
    listBgFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 10)

    -- 2. Configure the Backdrop
    -- This handles the tiling automatically and uses a texture known to work well.
    listBgFrame:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground", -- Nice dark rock texture
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", -- Optional: Matches WoW style
        tile = true,
        tileSize = 400,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    -- Optional: Darken it slightly if the rock is too bright
    listBgFrame:SetBackdropColor(0.25, 0.25, 0.25, 1)

    -- 3. SEARCH BOX
    -- Fits nicely inside our new Rock background
    searchBox = CreateFrame("EditBox", nil, listBgFrame, "InputBoxTemplate")
    searchBox:SetSize(280, 30)
    searchBox:SetPoint("TOP", listBgFrame, "TOP", 0, -12) -- Adjusted down slightly for the border
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(5, 5, 0, 0)
    searchBox:SetFontObject("ChatFontNormal")

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        if UpdateList then
            UpdateList()
        end
    end)

    -- =====================================================================
    -- SCROLL VIEW
    -- =====================================================================
    local scrollFrame = CreateFrame("ScrollFrame", nil, listBgFrame, "UIPanelScrollFrameTemplate")
    -- Starts below the search box
    scrollFrame:SetPoint("TOPLEFT", listBgFrame, "TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBgFrame, "BOTTOMRIGHT", -30, 10)

    scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(260, 500)
    scrollFrame:SetScrollChild(scrollChild)

    -- =====================================================================
    -- RIGHT COLUMN CONTAINER
    -- =====================================================================
    local rightPanel = CreateFrame("Frame", nil, mainFrame)
    rightPanel:SetPoint("TOPLEFT", listBgFrame, "TOPRIGHT", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -5, 5)

    -- 1. HEADER AREA (Top 20% - approx 120px height)
    local headerFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    headerFrame:SetHeight(120)
    headerFrame:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", 0, 0)
    headerFrame:SetBackdrop({
        bgFile = "Interface\\Collections\\CollectionsBackgroundTile",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 400,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    headerFrame:SetBackdropColor(1, 1, 1, 1)

    -- A. NAME & STATS (Centered at the TOP)
    nameText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    -- CHANGED: Anchor to TOP instead of CENTER
    nameText:SetPoint("TOP", headerFrame, "TOP", 0, -15)
    nameText:SetText("")

    countText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countText:SetScale(1.2)
    -- CHANGED: Reduced gap slightly to keep it compact
    countText:SetPoint("TOP", nameText, "BOTTOM", 0, -8)
    countText:SetText("")

    lastKillText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastKillText:SetPoint("TOP", countText, "BOTTOM", 0, -5)
    lastKillText:SetTextColor(0.7, 0.7, 0.7)
    lastKillText:SetText("")

    -- B. RANK DISPLAY (Moved to BOTTOM RIGHT)
    rankIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    rankIcon:SetSize(24, 24)
    -- CHANGED: Moved from TOPRIGHT to BOTTOMRIGHT
    rankIcon:SetPoint("BOTTOMRIGHT", headerFrame, "BOTTOMRIGHT", -15, 10)

    rankText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Anchored to the left of the icon, so it moves with it automatically
    rankText:SetPoint("RIGHT", rankIcon, "LEFT", -5, 0)
    rankText:SetJustifyH("RIGHT")
    rankText:SetTextColor(0.7, 0.7, 0.7)


    -- 2. MODEL AREA
    local modelFrame = CreateFrame("Frame", nil, rightPanel, "BackdropTemplate")
    modelFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    modelFrame:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", 0, 0)
    modelFrame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 6,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    modelFrame:SetBackdropColor(0.55, 0.55, 0.55, 1)
    -- B. THE BACKGROUND TEXTURE (Manual Creation)
    local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Spellbook\\Spellbook-Page-1")

    bg:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", -70, 0)
    bg:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", 50, -50)

    -- Match your color tint (use SetVertexColor for textures)
    bg:SetVertexColor(0.45, 0.45, 0.45, 1)

    -- D. CLIPPING
    -- This tells the frame: "If anything inside me sticks out (like our huge texture), CUT IT OFF."
    modelFrame:SetClipsChildren(true)

    modelView = CreateFrame("PlayerModel", nil, modelFrame)
    modelView:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 4, -4)
    modelView:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -4, 4)

    modelView.currentZoom = -2
    modelView.currentRotation = 0
    modelView:SetPosition(modelView.currentZoom, 0, 0)
    modelView:SetRotation(modelView.currentRotation)

    modelView:SetScript("OnMouseDown", function(self)
        self.isDragging = true
        local x, _ = GetCursorPosition()
        self.startX = x
        self.startRotation = self.currentRotation
    end)
    modelView:SetScript("OnMouseUp", function(self)
        self.isDragging = false
    end)
    modelView:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentX, _ = GetCursorPosition()
            local diff = (currentX - self.startX) / 80
            self.currentRotation = self.startRotation + diff
            self:SetRotation(self.currentRotation)
        end
    end)
    modelView:EnableMouseWheel(true)
    modelView:SetScript("OnMouseWheel", function(self, delta)
        local step = 0.5
        if delta > 0 then
            self.currentZoom = self.currentZoom + step
        else
            self.currentZoom = self.currentZoom - step
        end
        if self.currentZoom > 4 then
            self.currentZoom = 4
        end
        if self.currentZoom < -15 then
            self.currentZoom = -15
        end
        self:SetPosition(self.currentZoom, 0, 0)
    end)
end

-- =========================================================================
-- 3. LOGIC
-- =========================================================================

local function SelectMob(npcID)
    local data = MobCompendiumDB[npcID]
    if not data then
        return
    end

    -- Update State & Refresh List
    selectedNpcID = npcID
    UpdateList()

    nameText:SetText(data.name)
    countText:SetText("Killed: " .. data.kills)

    -- NEW: Display Last Kill Info
    if data.lastTime and data.lastX and data.lastY then
        -- Format: "Last Kill: 42.5, 60.1 (2025-03-09 20:15)"
        lastKillText:SetText(string.format("Last Kill: %.1f, %.1f  |cffaaaaaa(%s)|r", data.lastX, data.lastY, data.lastTime))
        lastKillText:Show()
    else
        lastKillText:Hide()
    end

    -- Update Rank Info in Header
    local rKey = data.rank or "normal"
    local rConfig = RANK_CONFIG[rKey] or RANK_CONFIG["normal"]

    rankText:SetText(rConfig.text)

    if rConfig.icon then
        rankIcon:Show()
        rankIcon:SetTexture(rConfig.icon)
        if rConfig.coords then
            rankIcon:SetTexCoord(unpack(rConfig.coords))
        end
        if rConfig.color then
            rankIcon:SetVertexColor(unpack(rConfig.color))
        else
            rankIcon:SetVertexColor(1, 1, 1)
        end
    else
        rankIcon:Hide()
    end

    -- Load the new creature
    modelView:SetCreature(npcID)
    modelView.currentZoom = 0
    modelView.currentRotation = 0
    modelView:SetPosition(0, 0, 0)
    modelView:SetRotation(0)
end

-- NEW: Helper function to toggle updates
-- Needs to be defined BEFORE UpdateList
local function ToggleZoneHeader(zoneName)
    local isExpanding = not expandedZones[zoneName]

    if IsAltKeyDown() then
        -- MODIFIER CLICK: Expand/Collapse ALL
        if isExpanding then
            -- If opening this one, open EVERYTHING
            for _, data in pairs(MobCompendiumDB) do
                local z = data.zone or "Unknown Zone"
                expandedZones[z] = true
            end
        else
            -- If closing this one, close EVERYTHING
            expandedZones = {}
        end
    else
        -- NORMAL CLICK: Toggle just this zone
        expandedZones[zoneName] = isExpanding
    end

    -- Refresh the list to show/hide items
    -- We need to call the global UpdateList (defined below)
    -- Note: Since UpdateList calls this, and this calls UpdateList, we need to be careful.
    -- But since this is triggered by OnClick, UpdateList is already defined by runtime.
    -- To be safe, we will call the global reference.
end

UpdateList = function()
    if not mainFrame or not mainFrame:IsShown() then
        return
    end

    local displayList = {}
    local zones = {}

    -- 1. GET SEARCH TEXT
    local searchText = ""
    if searchBox then
        searchText = strlower(searchBox:GetText() or "")
    end
    local isSearching = (searchText ~= "")

    -- 2. GROUP MOBS BY ZONE
    for id, data in pairs(MobCompendiumDB) do
        local z = data.zone or "Unknown Zone"
        local mobName = strlower(data.name or "")

        if not isSearching or string.find(mobName, searchText, 1, true) then
            if not zones[z] then
                zones[z] = { mobs = {}, type = "none" } -- Init with default type
            end

            -- DETECT ZONE TYPE
            -- If this mob was killed in a raid/dungeon, mark the ZONE as such.
            -- Priority: Raid > Party > Scenario > None
            local mType = data.instType or "none"
            if mType == "raid" then
                zones[z].type = "raid"
            elseif mType == "party" and zones[z].type ~= "raid" then
                zones[z].type = "party"
            elseif mType == "scenario" and zones[z].type == "none" then
                zones[z].type = "scenario"
            end

            table.insert(zones[z].mobs, {
                id = id,
                name = data.name,
                rank = data.rank or "normal"
            })
        end
    end

    local sortedZones = {}
    for zName, _ in pairs(zones) do
        table.insert(sortedZones, zName)
    end
    table.sort(sortedZones)

    -- 3. BUILD DISPLAY LIST
    for _, zName in ipairs(sortedZones) do
        local zoneData = zones[zName]
        local count = #zoneData.mobs
        local isExpanded = isSearching or expandedZones[zName]

        -- Add Header with TYPE info
        table.insert(displayList, {
            type = "HEADER",
            name = zName .. " (" .. count .. ")",
            rawZone = zName,
            instType = zoneData.type -- Pass the type to the renderer
        })

        if isExpanded then
            local mobsInZone = zoneData.mobs
            table.sort(mobsInZone, function(a, b)
                return a.name < b.name
            end)
            for _, mob in ipairs(mobsInZone) do
                table.insert(displayList, {
                    type = "MOB",
                    name = mob.name,
                    id = mob.id,
                    rank = mob.rank
                })
            end
            table.insert(displayList, { type = "SPACER", height = 10 })
        end
    end

    -- 4. RENDER BUTTONS
    local heightAccumulator = 0

    for i, item in ipairs(displayList) do
        local btn = buttons[i]
        if not btn then
            -- (Button Creation Code - Keep as is)
            btn = CreateFrame("Button", nil, scrollChild)
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(14, 14)
            btn.icon:SetPoint("LEFT", 5, 0)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetJustifyH("LEFT")
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(btn)
            hl:SetColorTexture(1, 1, 1, 0.2)
            btn.highlight = hl
            buttons[i] = btn
        end

        if item.type == "SPACER" then
            btn:Hide()
            heightAccumulator = heightAccumulator + item.height
        else
            btn:Show()
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, -heightAccumulator)
            btn:SetWidth(260)

            if item.type == "HEADER" then
                btn:SetHeight(26)

                -- ICON LOGIC: Use the Zone Type!
                local zType = item.instType or "none"
                local zConfig = ZONE_ICONS[zType] or ZONE_ICONS["none"]

                btn.icon:ClearAllPoints()
                btn.icon:SetPoint("LEFT", 5, 0)
                btn.icon:Show()
                btn.icon:SetTexture(zConfig.icon)
                btn.icon:SetVertexColor(unpack(zConfig.color))

                btn.text:ClearAllPoints()
                btn.text:SetPoint("LEFT", 25, 0)
                btn.text:SetFontObject("GameFontNormal")
                btn.text:SetText(item.name)
                btn.text:SetTextColor(1, 0.82, 0, 1)

                btn:EnableMouse(not isSearching)
                btn:SetScript("OnClick", function()
                    if not isSearching then
                        PlaySound(856)
                        ToggleZoneHeader(item.rawZone)
                        UpdateList()
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
                -- (Mob Row Logic - Keep exactly as is)
                btn:SetHeight(18)
                local rKey = item.rank or "normal"
                local rConfig = RANK_CONFIG[rKey]

                btn.icon:ClearAllPoints()
                btn.icon:SetPoint("LEFT", 20, 0)

                if rConfig and rConfig.icon then
                    btn.icon:Show()
                    btn.icon:SetTexture(rConfig.icon)
                    if rConfig.coords then
                        btn.icon:SetTexCoord(unpack(rConfig.coords))
                    end
                    if rConfig.color then
                        btn.icon:SetVertexColor(unpack(rConfig.color))
                    else
                        btn.icon:SetVertexColor(1, 1, 1)
                    end
                else
                    btn.icon:Hide()
                end

                btn.text:ClearAllPoints()
                btn.text:SetPoint("LEFT", 40, 0)

                if item.id == selectedNpcID then
                    btn.text:SetTextColor(0.2, 0.82, 1, 1)
                    btn.highlight:SetColorTexture(0.2, 0.82, 1, 0.2)
                else
                    btn.text:SetTextColor(1, 1, 1, 1)
                    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
                end

                btn.text:SetText(item.name)
                btn:SetScript("OnClick", function()
                    PlaySound(856);
                    SelectMob(item.id)
                end)
                btn:EnableMouse(true)
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

-- =========================================================================
-- 4. SLASH COMMANDS & EVENTS
-- =========================================================================

SLASH_MobCompendium1 = "/mobc"
SlashCmdList["MobCompendium"] = function(msg)
    if not mainFrame then
        CreateMobCompendiumUI()
        UpdateList()
        return
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show();
        UpdateList()
    end
end

-- NEW: RESET COMMAND
SLASH_MobCompendiumReset1 = "/mobcreset"
SlashCmdList["MobCompendiumReset"] = function(msg)
    -- 1. Wipe the Database
    MobCompendiumDB = {}

    -- 2. Reset UI State
    expandedZones = {}

    -- 3. Update Visuals if window is open
    if mainFrame and mainFrame:IsShown() then
        -- Clear the right panel
        nameText:SetText("")
        countText:SetText("")
        modelView:ClearModel()

        -- Refresh the list (which will now be empty)
        UpdateList()
    end

    print("|cff00ffffMobCompendium:|r Database has been reset.")
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- =========================================================================
-- 5. EVENT HANDLER (Tagging & Rank Logic)
-- =========================================================================

local recentTags = {}

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Helper: Given a token (e.g., "nameplate1"), return the simple rank string
local function ResolveRank(unitToken)
    if UnitCreatureType(unitToken) == "Critter" then
        return "critter"
    end
    local c = UnitClassification(unitToken)
    if c == "worldboss" then
        return "boss"
    end
    if c == "rareelite" then
        return "rareelite"
    end
    if c == "elite" then
        return "elite"
    end
    if c == "rare" then
        return "rare"
    end
    if c == "minus" then
        return "minion"
    end
    return "normal"
end

local function GetUnitRank(destGUID)
    if UnitGUID("target") == destGUID then
        return ResolveRank("target")
    end
    if UnitGUID("mouseover") == destGUID then
        return ResolveRank("mouseover")
    end
    if UnitGUID("focus") == destGUID then
        return ResolveRank("focus")
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitGUID(unit) == destGUID then
            return ResolveRank(unit)
        end
    end
    return nil
end

frame:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" and arg1 == "MobCompendium" then
        if MobCompendiumDB == nil then
            MobCompendiumDB = {}
        end
        print("|cff00ff00MobCompendium:|r Loaded successfully.")
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()

        -- 1. TRACKING TAGS
        if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
            if string.find(subEvent, "_DAMAGE") or string.find(subEvent, "_MISSED") or string.find(subEvent, "SPELL_AURA") then
                local unitType = strsplit("-", destGUID)
                if unitType == "Creature" then

                    local existingData = recentTags[destGUID]
                    local knownRank = existingData and existingData.rank

                    if not knownRank or knownRank == "normal" then
                        local foundRank = GetUnitRank(destGUID)
                        if foundRank then
                            if not existingData then
                                recentTags[destGUID] = { time = GetTime(), rank = foundRank }
                            else
                                recentTags[destGUID].time = GetTime()
                                recentTags[destGUID].rank = foundRank
                            end
                        elseif not existingData then
                            recentTags[destGUID] = { time = GetTime(), rank = "normal" }
                        else
                            recentTags[destGUID].time = GetTime()
                        end
                    else
                        recentTags[destGUID].time = GetTime()
                    end
                end
            end
        end

        -- 2. KILL CONFIRMATION
        if subEvent == "UNIT_DIED" then
            local unitType, _, _, _, _, npcID = strsplit("-", destGUID)

            if unitType == "Creature" then
                local tagData = recentTags[destGUID]
                local isTaggedByMe = tagData and (GetTime() - tagData.time < 60)

                if isTaggedByMe then
                    npcID = tonumber(npcID)

                    local capturedRank = tagData.rank or "normal"
                    if capturedRank == "normal" then
                        local lastResortRank = GetUnitRank(destGUID)
                        if lastResortRank and lastResortRank ~= "normal" then
                            capturedRank = lastResortRank
                        end
                    end

                    if not MobCompendiumDB then
                        MobCompendiumDB = {}
                    end
                    local status, zoneName = pcall(GetRealZoneText)
                    if not status or not zoneName then
                        zoneName = "Unknown Zone"
                    end

                    -- =========================================================
                    -- NEW: CAPTURE COORDINATES, TIME & INSTANCE TYPE
                    -- =========================================================
                    local posX, posY = 0, 0
                    local mapID = C_Map.GetBestMapForUnit("player")
                    if mapID then
                        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                        if pos then
                            posX, posY = pos.x * 100, pos.y * 100
                        end
                    end

                    local currentTime = date("%Y-%m-%d %H:%M")

                    -- CHECK INSTANCE TYPE
                    -- Returns: "none", "party" (Dungeon), "raid", "scenario", "pvp", "arena"
                    local _, instanceType = GetInstanceInfo()
                    -- =========================================================

                    if not MobCompendiumDB[npcID] then
                        -- NEW ENTRY
                        MobCompendiumDB[npcID] = {
                            name = destName,
                            kills = 1,
                            zone = zoneName,
                            rank = capturedRank,
                            lastX = posX,
                            lastY = posY,
                            lastTime = currentTime,
                            instType = instanceType
                        }
                        print("|cff00ffffMobCompendium:|r Discovered " .. destName .. " (" .. capturedRank .. ")!")
                    else
                        -- UPDATE ENTRY
                        MobCompendiumDB[npcID].kills = MobCompendiumDB[npcID].kills + 1
                        MobCompendiumDB[npcID].zone = zoneName
                        MobCompendiumDB[npcID].lastX = posX
                        MobCompendiumDB[npcID].lastY = posY
                        MobCompendiumDB[npcID].lastTime = currentTime

                        -- Always update instance type (in case you first killed it outside, then inside)
                        MobCompendiumDB[npcID].instType = instanceType

                        -- (Rank update logic omitted for brevity, keep your existing code here)
                        local currentDbRank = MobCompendiumDB[npcID].rank or "normal"
                        if currentDbRank == "normal" and capturedRank ~= "normal" then
                            MobCompendiumDB[npcID].rank = capturedRank
                        end
                        print("|cffaaaaaaMobCompendium:|r Recorded " .. destName .. " (Total: " .. MobCompendiumDB[npcID].kills .. ")")
                    end

                    recentTags[destGUID] = nil

                    if mainFrame and mainFrame:IsShown() then
                        UpdateList()
                        -- If we are currently looking at this mob, update the text immediately
                        if selectedNpcID == npcID then
                            SelectMob(npcID)
                        end
                    end
                end
            end
        end
    end
end)