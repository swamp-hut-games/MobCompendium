local _, NS = ...
NS.UI = NS.UI or {}

local mainFrame

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
    if NS.UI.RightColumn then
        NS.UI.RightColumn.Reset()
    end
end

function NS.CreateUI()
    if mainFrame then
        return
    end

    mainFrame = CreateFrame("Frame", "MobCompendiumMainWindow", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(1150, 600)
    
    if MobCompendiumDB and MobCompendiumDB.windowPos then
        local pos = MobCompendiumDB.windowPos
        mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
    
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")

    mainFrame:SetScript("OnDragStart", function(self)
        if not MobCompendiumDB.settings.lockWindow then
            self:StartMoving()
        end
    end)

    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        local p, _, rp, x, y = self:GetPoint();
        MobCompendiumDB.windowPos = { point = p, relativePoint = rp, x = x, y = y }
    end)

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
    
    if NS.UI.List then
        NS.UI.List.Init(mainFrame)
    end
    if NS.UI.Details then
        NS.UI.Details.Init(mainFrame)
    end
    if NS.UI.RightColumn then
        NS.UI.RightColumn.Init(mainFrame)
    end
end

function NS.ToggleUI()
    if not mainFrame then
        NS.CreateUI();
        NS.UpdateUI();
        return
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show();
        NS.UpdateUI()
    end
end