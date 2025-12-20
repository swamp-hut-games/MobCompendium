local _, NS = ...
NS.UI = NS.UI or {}

local mainFrame

-- Backwards compatibility wrapper for Core.lua
-- Core.lua calls NS.UpdateUI(), so we map it to the List update.
function NS.UpdateUI()
    if NS.UI.List and NS.UI.List.Update then
        NS.UI.List.Update()
    end
end

function NS.ResetUI()
    if NS.UI.List then
        NS.UI.List.Reset()
    end
    if NS.UI.Details then
        NS.UI.Details.Reset()
    end
end

function NS.CreateUI()
    if mainFrame then
        return
    end

    mainFrame = CreateFrame("Frame", "MobCompendiumMainWindow", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(900, 600)

    -- Load Position
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

    -- Sound & Title
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

    -- INITIALIZE SUB-MODULES
    -- We pass the mainFrame to them so they can attach their panels to it
    if NS.UI.List then
        NS.UI.List.Init(mainFrame)
    end
    if NS.UI.Details then
        NS.UI.Details.Init(mainFrame)
    end
end

function NS.ToggleUI()
    if not mainFrame then
        NS.CreateUI()
        NS.UpdateUI()
        return
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        NS.UpdateUI()
    end
end