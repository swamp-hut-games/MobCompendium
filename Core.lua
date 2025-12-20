local _, NS = ... -- Grab the private namespace
local frame = CreateFrame("Frame")
local recentTags = {}

-- =========================================================================
-- LOGIC & HELPERS
-- =========================================================================

-- Helper: Find the UnitID (token) for a specific GUID if it is visible
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

    -- Scan Nameplates
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitGUID(unit) == targetGUID then
            return unit
        end
    end
    return nil
end

local function ResolveRank(unitToken)
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

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MobCompendium" then
        if MobCompendiumDB == nil then
            MobCompendiumDB = {}
        end
        NS.InitSettings()
        print("|cff00ff00MobCompendium:|r Loaded successfully.")
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()

        -- 1. TRACKING TAGS
        if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
            if string.find(subEvent, "_DAMAGE") or string.find(subEvent, "_MISSED") or string.find(subEvent, "SPELL_AURA") then
                local unitType = strsplit("-", destGUID)
                if unitType == "Creature" then

                    local token = GetUnitToken(destGUID)
                    local currentData = recentTags[destGUID]

                    if token then
                        -- We see the unit (Target/Nameplate/Mouseover)
                        -- Capture the Type and Rank immediately
                        recentTags[destGUID] = {
                            time = GetTime(),
                            rank = ResolveRank(token),
                            type = UnitCreatureType(token)
                        }
                    elseif currentData then
                        -- We hit it blindly (DoT tick?), just update the timestamp
                        currentData.time = GetTime()
                    else
                        -- First hit and blind (Instant cast on something behind you?)
                        -- Initialize as unknown; will try to resolve at death or next hit
                        recentTags[destGUID] = {
                            time = GetTime(),
                            rank = "normal",
                            type = nil
                        }
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
                    local capturedType = tagData.type

                    -- Last ditch effort: If we missed the type (blind kill), 
                    -- check if we happen to be targeting/mousing over the corpse now.
                    if not capturedType or capturedRank == "normal" then
                        local token = GetUnitToken(destGUID)
                        if token then
                            if not capturedType then
                                capturedType = UnitCreatureType(token)
                            end
                            if capturedRank == "normal" then
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
                        -- NEW ENTRY
                        MobCompendiumDB[npcID] = {
                            name = destName,
                            kills = 1,
                            zone = zoneName,
                            rank = capturedRank,
                            type = capturedType,
                            lastX = posX, lastY = posY,
                            lastTime = currentTime,
                            instType = instanceType
                        }
                        if MobCompendiumDB.settings.printNew then
                            print("|cff00ffffMobCompendium:|r Discovered " .. destName .. " (" .. (capturedType or "Unknown") .. ")!")
                        end
                    else
                        -- UPDATE ENTRY
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
                        if not entry.type and capturedType then
                            entry.type = capturedType
                        end

                        if MobCompendiumDB.settings.printUpdate then
                            print("|cffaaaaaaMobCompendium:|r Recorded " .. destName .. " (Total: " .. entry.kills .. ")")
                        end
                    end
                    recentTags[destGUID] = nil

                    if NS.UpdateUI then
                        NS.UpdateUI()
                    end
                end
            end
        end
    end
end)