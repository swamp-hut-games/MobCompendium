local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.SpellList = {}

local scrollChild
local buttons = {}

function NS.UI.SpellList.Init(parent, anchorTop)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

    scrollFrame:SetPoint("TOP", anchorTop, "BOTTOM", 0, -5)
    scrollFrame:SetPoint("LEFT", parent, "LEFT", 10, 0)
    scrollFrame:SetPoint("RIGHT", parent, "RIGHT", -30, 0)
    scrollFrame:SetPoint("BOTTOM", parent, "BOTTOM", 0, 10)

    scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(260, 1)
    scrollFrame:SetScrollChild(scrollChild)
end

function NS.UI.SpellList.Reset()
    for _, btn in pairs(buttons) do
        btn:Hide()
    end
end

function NS.UI.SpellList.Update(data)
    for _, btn in pairs(buttons) do
        btn:Hide()
    end
    if not data or not data.spells then
        return
    end

    local list = {}
    for id, _ in pairs(data.spells) do
        table.insert(list, id)
    end
    table.sort(list)

    local height = 0
    for i, spellID in ipairs(list) do
        local btn = buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(260, 44)
            btn.icon = btn:CreateTexture(nil, "ARTWORK");
            btn.icon:SetSize(36, 36);
            btn.icon:SetPoint("LEFT", 4, 0)
            btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal");
            btn.name:SetPoint("LEFT", btn.icon, "RIGHT", 10, 8);
            btn.name:SetWidth(200);
            btn.name:SetJustifyH("LEFT")
            btn.sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
            btn.sub:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2);
            btn.sub:SetTextColor(0.6, 0.6, 0.6)
            btn.hl = btn:CreateTexture(nil, "HIGHLIGHT");
            btn.hl:SetAllPoints();
            btn.hl:SetColorTexture(1, 1, 1, 0.1)
            buttons[i] = btn
        end

        btn:Show()
        btn:SetPoint("TOPLEFT", 0, -height)

        -- Load Spell
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            btn.icon:SetTexture(spellInfo.iconID)
            btn.name:SetText(spellInfo.name)
        else
            btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            btn.name:SetText("Unknown Spell")
        end
        btn.name:SetTextColor(1, 1, 1)

        -- Interactions
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetSpellByID(spellID);
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function()
            if IsModifiedClick("CHATLINK") then
                local l = C_Spell.GetSpellLink(spellID);
                if l then
                    ChatEdit_InsertLink(l)
                end
            end
        end)

        height = height + 44
    end
    scrollChild:SetHeight(height)
end