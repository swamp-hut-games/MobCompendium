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

-- Manages tagging of mobs
local function TagMobs(subEvent, destGUID)

    if string.find(subEvent, "_DAMAGE") or string.find(subEvent, "_MISSED")
            or string.find(subEvent, "SPELL_AURA") or string.find(subEvent, "_INTERRUPT")
            or string.find(subEvent, "_DISPEL") or string.find(subEvent, "_STOLEN") then

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

local function GetContinentName(mapID)
    if not mapID then
        return nil
    end

    local currentMapID = mapID
    local loopSafety = 0

    while currentMapID and loopSafety < 10 do
        local info = C_Map.GetMapInfo(currentMapID)
        if not info then
            break
        end

        if info.mapType == Enum.UIMapType.Continent then
            return info.name
        end

        if info.mapType == Enum.UIMapType.Cosmic or info.mapType == Enum.UIMapType.World then
            return nil
        end

        currentMapID = info.parentMapID
        loopSafety = loopSafety + 1
    end

    return nil
end

-- =========================================================================
-- Event Functions
-- =========================================================================

-- Gets called once the Addon loads
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
local function OnLootOpened()
    local numItems = GetNumLootItems()
    if numItems > 0 then

        local mapID = C_Map.GetBestMapForUnit("player")
        local _, instanceType, difficultyID = GetInstanceInfo()
        local isInInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "pvp")

        -- Default to mapID, but append Difficulty ID if in instance to separate Normal/Heroic/Mythic
        local encounterKey = mapID
        if mapID and isInInstance and difficultyID then
            encounterKey = mapID .. ":" .. difficultyID
        end

        for i = 1, numItems do
            local sourceGUID = GetLootSourceInfo(i)
            if sourceGUID and encounterKey then

                if not lootCache[sourceGUID] then
                    lootCache[sourceGUID] = {}
                end

                local unitType, _, _, _, _, npcID, _ = strsplit("-", sourceGUID)
                if unitType == "Creature" then
                    npcID = tonumber(npcID)
                    if GetLootSlotType(i) == Enum.LootSlotType.Item then
                        local link = GetLootSlotLink(i)
                        if link then
                            local itemID = GetItemInfoInstant(link)
                            if itemID then
                                if not lootCache[sourceGUID][itemID] then

                                    if not MobCompendiumDB[npcID] then
                                        MobCompendiumDB[npcID] = {
                                            name = "Unknown (Looted)",
                                            encounters = {},
                                            spells = {}
                                        }
                                    end

                                    if not MobCompendiumDB[npcID].encounters[encounterKey] then
                                        MobCompendiumDB[npcID].encounters[encounterKey] = {
                                            zoneName = "Unknown (Looted)",
                                            drops = {},
                                            kills = 0
                                        }
                                    end

                                    MobCompendiumDB[npcID].encounters[encounterKey].drops[itemID] = true
                                    lootCache[sourceGUID][itemID] = true
                                end
                            end
                        end
                    end
                end
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

local function OnCombatUnitDied(destGUID, destName)
    local unitType, _, _, _, _, npcID = strsplit("-", destGUID)

    if unitType == "Creature" then
        local tagData = recentTags[destGUID]
        local isTagged = tagData and (GetTime() - tagData.time < 60)

        if isTagged then
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

            local mapID = C_Map.GetBestMapForUnit("player")
            local zoneName = "Unknown Zone"
            local parentMapName = nil

            if mapID then
                local mapInfo = C_Map.GetMapInfo(mapID)
                if mapInfo and mapInfo.name then
                    zoneName = mapInfo.name
                end
            end

            local instName, instanceType, difficultyID, difficultyName = GetInstanceInfo()
            local isInInstance = (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "pvp")

            if isInInstance and instName and instName ~= "" then
                parentMapName = instName
                if zoneName == "Unknown Zone" then
                    zoneName = instName
                end
            else
                parentMapName = GetContinentName(mapID)
                if not parentMapName and mapID then
                    local mapInfo = C_Map.GetMapInfo(mapID)
                    if mapInfo and mapInfo.parentMapID then
                        local pInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
                        if pInfo then
                            parentMapName = pInfo.name
                        end
                    end
                end
            end

            -- Sanitize Names
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

            if parentMapName == zoneName then
                zoneName = "General"
            end
            if not parentMapName then
                parentMapName = "Unknown Region"
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

            local posX, posY = nil, nil
            if mapID then
                local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                if pos then
                    posX, posY = pos.x * 100, pos.y * 100
                end
            end
            
            local currentTime = date("%Y-%m-%d %H:%M")

            local encounterKey = mapID
            if mapID and isInInstance and difficultyID then
                encounterKey = mapID .. ":" .. difficultyID
            end

            if not MobCompendiumDB[npcID] then
                MobCompendiumDB[npcID] = {
                    name = destName,
                    spells = {},
                    encounters = {}
                }
                if tempSpellCache[destGUID] then
                    for sID, _ in pairs(tempSpellCache[destGUID]) do
                        MobCompendiumDB[npcID].spells[sID] = true
                    end
                end
                if MobCompendiumDB.settings.printNew then
                    print("|cff00ffffMobCompendium:|r Discovered " .. destName .. " (" .. (capturedType or "Unknown") .. ")!")
                end
            end

            local entry = MobCompendiumDB[npcID]

            if not entry.encounters[encounterKey] then
                entry.encounters[encounterKey] = {
                    zoneName = zoneName,
                    parentMap = parentMapName,
                    instType = instanceType,
                    diffName = shortDiff,
                    drops = {},
                    kills = 0,
                    rank = capturedRank,
                    type = capturedType
                }
            end

            local encounter = entry.encounters[encounterKey]
            encounter.kills = encounter.kills + 1
            encounter.lastX = posX
            encounter.lastY = posY
            encounter.lastTime = currentTime
            encounter.zoneName = zoneName
            encounter.parentMap = parentMapName
            encounter.diffName = shortDiff

            if (encounter.rank or "unknown") == "unknown" and capturedRank ~= "unknown" then
                encounter.rank = capturedRank
            end
            if not encounter.type and capturedType then
                encounter.type = capturedType
            end

            entry.name = destName

            if MobCompendiumDB.settings.printUpdate then
                local printZone = zoneName
                if shortDiff ~= "" then
                    printZone = printZone .. " (" .. shortDiff .. ")"
                end
                print("|cffaaaaaaMobCompendium:|r Recorded " .. destName .. " (Total Kills in " .. printZone .. ": " .. encounter.kills .. ")")
            end

            recentTags[destGUID] = nil
            tempSpellCache[destGUID] = nil
            if NS.UpdateUI then
                NS.UpdateUI()
            end
        end
    end
end

-- Gets called everytime a combat log event happens
local function OnCombatLogEvent()

    local _, subEvent, _, sourceGUID, _, sourceFlags, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
    local isGroup = false

    if subEvent == "SPELL_CAST_START" or subEvent == "SPELL_CAST_SUCCESS" then
        local unitType, _, _, _, _, npcID = strsplit("-", sourceGUID)
        if unitType == "Creature" then
            OnCombatEnemySpellCast(npcID, spellID, sourceGUID)
        end
    end

    if sourceFlags then
        local AFFILIATION_GROUP = bit.bor(
                COMBATLOG_OBJECT_AFFILIATION_MINE,
                COMBATLOG_OBJECT_AFFILIATION_PARTY,
                COMBATLOG_OBJECT_AFFILIATION_RAID
        )
        if bit.band(sourceFlags, AFFILIATION_GROUP) > 0 then
            isGroup = true
        end
    end

    if isGroup then
        TagMobs(subEvent, destGUID)
    end

    if subEvent == "UNIT_DIED" then
        OnCombatUnitDied(destGUID, destName)
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