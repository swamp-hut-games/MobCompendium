local _, NS = ...
local frame = CreateFrame("Frame")
local recentTags = {}
local lootCache = {}      -- Tracks scanned corpses (GUIDs)
local tempSpellCache = {} -- Temporarily stores spells seen during combat

-- =========================================================================
-- Commands
-- =========================================================================

SLASH_MobCompendium1 = "/mobc"
SlashCmdList["MobCompendium"] = function()
    NS.ToggleUI()
end

SLASH_MobCompendiumReset1 = "/mobcreset"
SlashCmdList["MobCompendiumReset"] = function()
    MobCompendiumDB = {}
    NS.InitSettings()
    NS.ResetUI()
    print("|cff00ffffMobCompendium:|r Database has been reset.")
end

-- =========================================================================
-- Helper Functions
-- =========================================================================

local function ClearTempCache()
    lootCache = {}
    tempSpellCache = {}
end

local function GetUnitToken(targetGUID)

    if UnitGUID("target") == targetGUID then
        return "target"
    end

    if UnitGUID("mouseover") == targetGUID then
        return "mouseover"
    end

    if UnitGUID("focus") == targetGUID then
        return "focus"
    end

    if UnitGUID("softenemy") == targetGUID then
        return "softenemy"
    end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitGUID(unit) == targetGUID then
            return unit
        end
    end

    return nil

end

-- Gets the unit rank for a unit (e.g. Critter, Elite, Rare)
local function ResolveRank(unitToken)

    if UnitIsWildBattlePet(unitToken) then
        return "wildpet"
    end

    local cType = UnitCreatureType(unitToken)

    if cType == "Critter" then
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

-- =========================================================================
-- Event Functions
-- =========================================================================

local function OnAddonLoaded()
    if MobCompendiumDB == nil then
        MobCompendiumDB = {}
    end
    NS.InitSettings()
    print("|cff00ff00MobCompendium:|r Loaded successfully.")
end

local function OnPlayerEnterWorld()
    ClearTempCache()
end

-- Gets called whenever the player opens the loot window
-- TODO: When enemy does not have loot, but can be skinned, reagent will track, but NOT if it has loot and can be skinned.
local function OnLootOpened()

    local numItems = GetNumLootItems()

    if numItems > 0 then
        for i = 1, numItems do
            local sourceGUID = GetLootSourceInfo(i)

            if sourceGUID and not lootCache[sourceGUID] then

                -- [unitType]-0-[serverID]-[instanceID]-[zoneUID]-[ID]-[spawnUID]
                local unitType, _, _, _, _, npcID, _ = strsplit("-", sourceGUID)

                if unitType == "Creature" then
                    npcID = tonumber(npcID)

                    if GetLootSlotType(i) == Enum.LootSlotType.Item then
                        local link = GetLootSlotLink(i)

                        if link then

                            local itemID = GetItemInfoInstant(link)

                            if itemID then

                                if not MobCompendiumDB[npcID] then
                                    MobCompendiumDB[npcID] = {
                                        name = "Unknown (Looted)",
                                        kills = 0,
                                        drops = {},
                                        spells = {}
                                    }
                                end

                                if not MobCompendiumDB[npcID].drops then
                                    MobCompendiumDB[npcID].drops = {}
                                end

                                MobCompendiumDB[npcID].drops[itemID] = true

                            end
                        end
                    end
                end
            end
        end

        -- Cache loot sources to only process them once (e.g. when aborting looting)
        for i = 1, numItems do
            local sourceGUID = GetLootSourceInfo(i)
            if sourceGUID then
                lootCache[sourceGUID] = true
            end
        end

    end
end

local function OnCombatEnemySpellCast(npcID, spellID, sourceGUID)

    npcID = tonumber(npcID)

    if MobCompendiumDB[npcID] then
        if not MobCompendiumDB[npcID].spells then
            MobCompendiumDB[npcID].spells = {}
        end
        if not MobCompendiumDB[npcID].spells[spellID] then
            MobCompendiumDB[npcID].spells[spellID] = true
        end
    else
        if not tempSpellCache[sourceGUID] then
            tempSpellCache[sourceGUID] = {}
        end

        tempSpellCache[sourceGUID][spellID] = true

    end
end

-- Gets called everytime a combat log event happens
local function OnCombatLogEvent()

    local _, subEvent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()

    if subEvent == "SPELL_CAST_START" or subEvent == "SPELL_CAST_SUCCESS" then
        local unitType, _, _, _, _, npcID = strsplit("-", sourceGUID)
        if unitType == "Creature" then
            OnCombatEnemySpellCast(npcID, spellID, sourceGUID)
        end
    end

    if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
        if string.find(subEvent, "_DAMAGE") or string.find(subEvent, "_MISSED") or string.find(subEvent, "SPELL_AURA") then
            local unitType = strsplit("-", destGUID)
            if unitType == "Creature" then
                local token = GetUnitToken(destGUID)
                local currentData = recentTags[destGUID]
                if token then
                    recentTags[destGUID] = {
                        time = GetTime(),
                        rank = ResolveRank(token),
                        type = UnitCreatureType(token)
                    }
                elseif currentData then
                    currentData.time = GetTime()
                else
                    recentTags[destGUID] = { time = GetTime(), rank = "unknown", type = nil }
                end
            end
        end
    end

    if subEvent == "UNIT_DIED" then
        local unitType, _, _, _, _, npcID = strsplit("-", destGUID)
        if unitType == "Creature" then
            local tagData = recentTags[destGUID]
            local isTaggedByMe = tagData and (GetTime() - tagData.time < 60)

            if isTaggedByMe then
                npcID = tonumber(npcID)

                local capturedRank = tagData.rank or "unknown"
                local capturedType = tagData.type

                if not capturedType or capturedRank == "unknown" then
                    local token = GetUnitToken(destGUID)
                    if token then
                        if not capturedType then
                            capturedType = UnitCreatureType(token)
                        end
                        if capturedRank == "unknown" then
                            capturedRank = ResolveRank(token)
                        end
                    end
                end

                local zoneName = "Unknown Zone"
                local parentMapName = nil

                local mapID = C_Map.GetBestMapForUnit("player")
                local instName, instanceType, _, difficultyName = GetInstanceInfo()
                local isInInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "pvp")

                if isInInstance and instName and instName ~= "" then
                    zoneName = instName

                elseif mapID then
                    local mapInfo = C_Map.GetMapInfo(mapID)
                    if mapInfo and mapInfo.name then
                        zoneName = mapInfo.name

                        if mapInfo.parentMapID then
                            local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
                            if parentInfo and parentInfo.name then
                                parentMapName = parentInfo.name
                            end
                        end

                    end
                end

                -- Sometimes the zone/map names have (Surface) in them, I don't want this info.
                if zoneName then
                    zoneName = zoneName:gsub("%s*%(Surface%)", "")
                    if string.match(zoneName, "^%d") then
                        zoneName = "Unknown Zone"
                    end
                end
                if parentMapName then
                    parentMapName = parentMapName:gsub("%s*%(Surface%)", "")
                    if string.match(parentMapName, "^%d") then
                        parentMapName = nil
                    end
                end

                local shortDiff = ""
                if isInInstance and difficultyName then
                    if string.find(difficultyName, "Mythic") then
                        shortDiff = "M"
                    elseif string.find(difficultyName, "Heroic") then
                        shortDiff = "H"
                    elseif string.find(difficultyName, "Normal") then
                        shortDiff = "N"
                    end
                end

                local posX, posY = 0, 0
                if mapID then
                    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                    if pos then
                        posX, posY = pos.x * 100, pos.y * 100
                    end
                end

                local currentTime = date("%Y-%m-%d %H:%M")

                if not MobCompendiumDB[npcID] then
                    MobCompendiumDB[npcID] = {
                        name = destName,
                        kills = 1,
                        zone = zoneName,
                        parentMap = parentMapName,
                        rank = capturedRank,
                        type = capturedType,
                        lastX = posX, lastY = posY,
                        lastTime = currentTime,
                        instType = instanceType,
                        diffName = shortDiff,
                        mapID = mapID,
                        drops = {},
                        spells = {}
                    }

                    if tempSpellCache[destGUID] then
                        for sID, _ in pairs(tempSpellCache[destGUID]) do
                            MobCompendiumDB[npcID].spells[sID] = true
                        end
                    end

                    if MobCompendiumDB.settings.printNew then
                        print("|cff00ffffMobCompendium:|r Discovered " .. destName .. " (" .. (capturedType or "Unknown") .. ")!")
                    end
                else
                    local entry = MobCompendiumDB[npcID]
                    entry.kills = entry.kills + 1
                    entry.zone = zoneName
                    entry.parentMap = parentMapName
                    entry.lastX = posX
                    entry.lastY = posY
                    entry.lastTime = currentTime
                    entry.instType = instanceType
                    entry.diffName = shortDiff
                    entry.mapID = mapID

                    -- Killing mobs too quickly (e.g. Critters or Low Level mobs) will not track correctly sometimes
                    -- Players can update the database when killing those exceptions while targeting them.
                    local dbRank = entry.rank or "unknown"
                    if dbRank == "unknown" and capturedRank ~= "unknown" then
                        entry.rank = capturedRank
                    elseif dbRank == "normal" and (capturedRank ~= "normal" and capturedRank ~= "unknown") then
                        entry.rank = capturedRank
                    end

                    if not entry.type and capturedType then
                        entry.type = capturedType
                    end

                    if MobCompendiumDB.settings.printUpdate then
                        print("|cffaaaaaaMobCompendium:|r Recorded " .. destName .. " (Total: " .. entry.kills .. ")")
                    end
                end

                recentTags[destGUID] = nil
                tempSpellCache[destGUID] = nil

                if NS.UpdateUI then
                    NS.UpdateUI()
                end
            end
        end
    end
end

-- =========================================================================
-- Event Handlers
-- =========================================================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" and arg1 == "MobCompendium" then
        OnAddonLoaded()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnterWorld()
        return
    end

    if event == "LOOT_OPENED" then
        OnLootOpened()
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    end

end)