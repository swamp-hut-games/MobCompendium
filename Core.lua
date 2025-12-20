local _, NS = ... -- Grab the private namespace
local frame = CreateFrame("Frame")
local recentTags = {}

-- =========================================================================
-- LOGIC & HELPERS
-- =========================================================================

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
    NS.ResetUI()
    print("|cff00ffffMobCompendium:|r Database has been reset.")
end

-- =========================================================================
-- EVENT HANDLERS
-- =========================================================================

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

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
                            recentTags[destGUID] = { time = GetTime(), rank = foundRank }
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
                            lastX = posX, lastY = posY,
                            lastTime = currentTime,
                            instType = instanceType
                        }
                        print("|cff00ffffMobCompendium:|r Discovered " .. destName .. " (" .. capturedRank .. ")!")
                    else
                        local entry = MobCompendiumDB[npcID]
                        entry.kills = entry.kills + 1
                        entry.zone = zoneName
                        entry.lastX = posX
                        entry.lastY = posY
                        entry.lastTime = currentTime
                        entry.instType = instanceType
                        if (entry.rank or "normal") == "normal" and capturedRank ~= "normal" then
                            entry.rank = capturedRank
                        end
                        print("|cffaaaaaaMobCompendium:|r Recorded " .. destName .. " (Total: " .. entry.kills .. ")")
                    end
                    recentTags[destGUID] = nil

                    -- Call the Shared Namespace Function to update UI
                    if NS.UpdateUI then
                        NS.UpdateUI()
                    end
                end
            end
        end
    end
end)