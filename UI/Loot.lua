local _, NS = ...
NS.UI = NS.UI or {}
NS.UI.Loot = {}

local lootScrollChild, spellScrollChild
local lootButtons = {}
local spellButtons = {}

-- =========================================================================
-- HELPER: Create Generic List Button (Used for both Loot & Spells)
-- =========================================================================
local function CreateListButton(parent, pool, index)
    local btn = pool[index]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:SetSize(260, 44)

        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(36, 36)
        btn.icon:SetPoint("LEFT", 4, 0)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        -- Name
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.name:SetPoint("LEFT", btn.icon, "RIGHT", 10, 8)
        btn.name:SetJustifyH("LEFT")
        btn.name:SetWidth(200)
        btn.name:SetWordWrap(false)

        -- Subtext
        btn.sub = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.sub:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2)
        btn.sub:SetTextColor(0.6, 0.6, 0.6)

        -- Highlight
        btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hl:SetAllPoints(btn)
        btn.hl:SetColorTexture(1, 1, 1, 0.1)

        pool[index] = btn
    end
    return btn
end

-- =========================================================================
-- INITIALIZATION
-- =========================================================================
function NS.UI.Loot.Init(mainFrame)
    -- 1. Main Container (Right Column)
    local rightPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    rightPanel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -22)
    rightPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)
    rightPanel:SetWidth(300)

    rightPanel:SetBackdrop({
        bgFile = "Interface\\AchievementFrame\\UI-Achievement-StatsBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 400, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    rightPanel:SetBackdropColor(0.25, 0.25, 0.25, 1)

    -- 2. LOOT SECTION (Top Half)
    local lootTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    lootTitle:SetPoint("TOP", rightPanel, "TOP", 0, -12)
    lootTitle:SetText("Known Loot")
    lootTitle:SetTextColor(1, 0.82, 0)

    local lootScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    lootScroll:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, -40)
    lootScroll:SetPoint("RIGHT", rightPanel, "RIGHT", -30, 0)
    lootScroll:SetHeight(230) -- Top half height

    lootScrollChild = CreateFrame("Frame")
    lootScrollChild:SetSize(260, 1)
    lootScroll:SetScrollChild(lootScrollChild)

    -- 3. DIVIDER
    local divider = rightPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.2)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", lootScroll, "BOTTOMLEFT", -5, -15)
    divider:SetPoint("TOPRIGHT", lootScroll, "BOTTOMRIGHT", 25, -15)

    -- 4. SPELL SECTION (Bottom Half)
    local spellTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spellTitle:SetPoint("TOP", divider, "BOTTOM", 0, -15)
    spellTitle:SetText("Known Abilities")
    spellTitle:SetTextColor(1, 0.82, 0)

    local spellScroll = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    spellScroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -45)
    spellScroll:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -30, 10)

    spellScrollChild = CreateFrame("Frame")
    spellScrollChild:SetSize(260, 1)
    spellScroll:SetScrollChild(spellScrollChild)
end

function NS.UI.Loot.Reset()
    for _, btn in pairs(lootButtons) do
        btn:Hide()
    end
    for _, btn in pairs(spellButtons) do
        btn:Hide()
    end
end

-- =========================================================================
-- UPDATE LOGIC
-- =========================================================================
local function UpdateLootList(data)
    for _, btn in pairs(lootButtons) do
        btn:Hide()
    end
    if not data or not data.drops then
        return
    end

    local list = {}
    for id, _ in pairs(data.drops) do
        table.insert(list, id)
    end
    table.sort(list)

    local height = 0
    for i, itemID in ipairs(list) do
        local btn = CreateListButton(lootScrollChild, lootButtons, i)
        btn:Show()
        btn:SetPoint("TOPLEFT", 0, -height)

        -- Reset visuals
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.name:SetText("Loading...")
        btn.name:SetTextColor(1, 1, 1)

        -- Load Item Data
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local itemName, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
            btn.icon:SetTexture(icon)
            if itemName then
                local r, g, b = GetItemQualityColor(quality or 1)
                btn.name:SetText(itemName)
                btn.name:SetTextColor(r, g, b)
            else
                btn.name:SetText("Unknown Item")
            end
        end)

        -- Interaction
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function()
            if IsModifiedClick("CHATLINK") then
                local _, link = GetItemInfo(itemID)
                if link then
                    ChatEdit_InsertLink(link)
                end
            end
        end)

        height = height + 44
    end
    lootScrollChild:SetHeight(height)
end

local function UpdateSpellList(data)
    for _, btn in pairs(spellButtons) do
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
        local btn = CreateListButton(spellScrollChild, spellButtons, i)
        btn:Show()
        btn:SetPoint("TOPLEFT", 0, -height)

        -- FIX: Use C_Spell.GetSpellInfo API (Returns a table now)
        local spellInfo = C_Spell.GetSpellInfo(spellID)

        if spellInfo then
            btn.icon:SetTexture(spellInfo.iconID)
            btn.name:SetText(spellInfo.name)
        else
            btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            btn.name:SetText("Unknown Spell")
        end

        btn.name:SetTextColor(1, 1, 1)

        -- Interaction
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            if IsModifiedClick("CHATLINK") then
                local link = C_Spell.GetSpellLink(spellID)
                if link then
                    ChatEdit_InsertLink(link)
                end
            end
        end)

        height = height + 44
    end
    spellScrollChild:SetHeight(height)
end

-- MAIN UPDATE FUNCTION
function NS.UI.Loot.Update(npcID)
    local data = MobCompendiumDB[npcID]
    UpdateLootList(data)
    UpdateSpellList(data)
end