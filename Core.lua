local _, NS = ...
local frame = CreateFrame("Frame")
local recentTags = {}
local lootCache = {}      -- Tracks scanned corpses (GUIDs)
local tempSpellCache = {} -- Temporarily stores spells seen during combat

-- =========================================================================
-- LOGIC & HELPERS
-- =========================================================================

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

local function ResolveRank(unitToken)

    if UnitIsWildBattlePet(unitToken) then
        return "wildpet"
    end

    local cType = UnitCreatureType(unitToken)
    if cType == "Critter" or cType == "Wildtier" then
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
-- SLASH COMMANDS
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
-- EVENT HANDLERS
-- =========================================================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MobCompendium" then
        if MobCompendiumDB == nil then
            MobCompendiumDB = {}
        end
        NS.InitSettings()
        print("|cff00ff00MobCompendium:|r Loaded successfully.")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        lootCache = {}
        tempSpellCache = {}
        return
    end

    -- 3. LOOT TRACKING
    if event == "LOOT_OPENED" then
        local numItems = GetNumLootItems()
        if numItems > 0 then
            for i = 1, numItems do
                local sourceGUID = GetLootSourceInfo(i)
                if sourceGUID and not lootCache[sourceGUID] then
                    local unitType, _, _, _, _, npcID = strsplit("-", sourceGUID)
                    if unitType == "Creature" then
                        npcID = tonumber(npcID)
                        if GetLootSlotType(i) == 1 then
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
            for i = 1, numItems do
                local sGUID = GetLootSourceInfo(i)
                if sGUID then
                    lootCache[sGUID] = true
                end
            end
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()

        -- 4. SPELL TRACKING
        if subEvent == "SPELL_CAST_START" or subEvent == "SPELL_CAST_SUCCESS" then
            local unitType, _, _, _, _, npcID = strsplit("-", sourceGUID)
            if unitType == "Creature" then
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
        end

        -- 1. TRACKING TAGS
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

        -- 2. KILL CONFIRMATION
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

                    local status, zoneName = pcall(GetRealZoneText)
                    if not status or not zoneName then
                        zoneName = "Unknown Zone"
                    end

                    local posX, posY = 0, 0
                    local mapID = C_Map.GetBestMapForUnit("player")
                    if mapID then
                        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                        if pos then
                            posX, posY = pos.x * 100, pos.y * 100
                        end
                    end

                    local _, instanceType = GetInstanceInfo()
                    local currentTime = date("%Y-%m-%d %H:%M")

                    if not MobCompendiumDB[npcID] then
                        MobCompendiumDB[npcID] = {
                            name = destName,
                            kills = 1,
                            zone = zoneName,
                            rank = capturedRank,
                            type = capturedType,
                            lastX = posX, lastY = posY,
                            lastTime = currentTime,
                            instType = instanceType,
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
                        entry.lastX = posX
                        entry.lastY = posY
                        entry.lastTime = currentTime
                        entry.instType = instanceType

                        -- DATA HEALING
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
end)