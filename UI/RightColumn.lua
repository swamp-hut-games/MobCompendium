local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.RightColumn = {}

local rightPanel

function NS.UI.RightColumn.Init(mainFrame)

    rightPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    rightPanel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -22)
    rightPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 45)
    rightPanel:SetWidth(300)

    rightPanel:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    rightPanel:SetBackdropColor(0.25, 0.25, 0.25, 1)

    local lootTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lootTitle:SetPoint("TOP", rightPanel, "TOP", 0, -12)
    lootTitle:SetText("Known Loot")
    lootTitle:SetTextColor(1, 0.82, 0)

    local divider = rightPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.2)
    divider:SetHeight(1)
    divider:SetPoint("LEFT", 10, 0)
    divider:SetPoint("RIGHT", -10, 0)
    divider:SetPoint("TOP", rightPanel, "TOP", 0, -280)

    local spellTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellTitle:SetPoint("TOP", divider, "BOTTOM", 0, -15)
    spellTitle:SetText("Known Abilities")
    spellTitle:SetTextColor(1, 0.82, 0)

    if NS.UI.LootList then
        NS.UI.LootList.Init(rightPanel, lootTitle, divider)
    end

    if NS.UI.SpellList then
        NS.UI.SpellList.Init(rightPanel, spellTitle)
    end
end

function NS.UI.RightColumn.Reset()
    if NS.UI.LootList then
        NS.UI.LootList.Reset()
    end
    if NS.UI.SpellList then
        NS.UI.SpellList.Reset()
    end
end

function NS.UI.RightColumn.Update(npcID)
    local data = MobCompendiumDB[npcID]

    if NS.UI.LootList then
        NS.UI.LootList.Update(data)
    end
    if NS.UI.SpellList then
        NS.UI.SpellList.Update(data)
    end
end