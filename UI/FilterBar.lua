local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.FilterBar = {}

local RANK_DISPLAY_ORDER = {
    "boss", "rareelite", "elite", "rare", "normal", "minion", "critter", "wildpet", "unknown"
}

local checkButtons = {}

function NS.UI.FilterBar.Init(mainFrame)
    local filterBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")

    filterBar:SetHeight(40)

    -- Anchor to the bottom inside the main frame
    filterBar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 4)
    filterBar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)

    -- Visual Style
    filterBar:SetBackdrop({
        bgFile = "Interface\\Collections\\CollectionsBackgroundTile",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    filterBar:SetBackdropColor(1, 1, 1, 1)

    local prevAnchor = nil

    for _, rankKey in ipairs(RANK_DISPLAY_ORDER) do
        local config = NS.RANK_CONFIG[rankKey]
        if config then
            local cb = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
            cb:SetSize(24, 24)
            cb.rankKey = rankKey
            checkButtons[rankKey] = cb

            if prevAnchor then
                cb:SetPoint("LEFT", prevAnchor, "RIGHT", 15, 0)
            else
                cb:SetPoint("LEFT", filterBar, "LEFT", 15, 0)
            end

            cb.icon = cb:CreateTexture(nil, "ARTWORK")
            cb.icon:SetSize(18, 18)
            cb.icon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            cb.icon:SetTexture(config.icon)

            if config.coords then
                cb.icon:SetTexCoord(unpack(config.coords))
            end
            if config.color then
                cb.icon:SetVertexColor(unpack(config.color))
            end

            cb.text:SetText(config.text)
            cb.text:SetFontObject("GameFontNormal")
            cb.text:ClearAllPoints()
            cb.text:SetPoint("LEFT", cb.icon, "RIGHT", 5, 0)

            cb:SetChecked(true)
            cb:SetScript("OnClick", function(self)
                local isChecked = self:GetChecked()
                PlaySound(isChecked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
                
                if NS.UI.List and NS.UI.List.Update then
                    NS.UI.List.Update()
                end
            end)

            prevAnchor = cb.text
        end
    end

    NS.UI.FilterBar.frame = filterBar
end

function NS.UI.FilterBar.GetState()
    local state = {}
    for key, cb in pairs(checkButtons) do
        state[key] = cb:GetChecked()
    end
    return state
end