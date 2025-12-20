local _, NS = ...

-- Default Configuration
local defaultSettings = {
    lockWindow = false,
    printNew = true,
    printUpdate = true
}

function NS.InitSettings()
    -- 1. Ensure DB has settings table
    if not MobCompendiumDB.settings then
        MobCompendiumDB.settings = CopyTable(defaultSettings)
    else
        -- Backfill new defaults for existing users (e.g. if they updated from v0.3)
        for k, v in pairs(defaultSettings) do
            if MobCompendiumDB.settings[k] == nil then
                MobCompendiumDB.settings[k] = v
            end
        end
    end

    -- 2. Create the Options Panel Frame
    local panel = CreateFrame("Frame")
    panel.name = "Mob Compendium"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mob Compendium Settings")

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure the behavior of the Mob Compendium.")

    -- ---------------------------------------------------------------------
    -- SETTING: Lock Window
    -- ---------------------------------------------------------------------
    local cbLock = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbLock:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    cbLock.Text:SetText("Lock Main Window")

    cbLock:SetChecked(MobCompendiumDB.settings.lockWindow)
    cbLock:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        MobCompendiumDB.settings.lockWindow = isChecked

        -- Apply immediately
        local win = _G["MobCompendiumMainWindow"]
        if win then
            win:SetMovable(not isChecked)
            if isChecked then
                win:RegisterForDrag() -- Disable drag
            else
                win:RegisterForDrag("LeftButton") -- Enable drag
            end
        end
    end)

    -- ---------------------------------------------------------------------
    -- SETTING: Print New Discoveries
    -- ---------------------------------------------------------------------
    local cbPrintNew = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbPrintNew:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -10)
    cbPrintNew.Text:SetText("Chat Message: New Discovery")

    cbPrintNew:SetChecked(MobCompendiumDB.settings.printNew)
    cbPrintNew:SetScript("OnClick", function(self)
        MobCompendiumDB.settings.printNew = self:GetChecked()
    end)

    -- ---------------------------------------------------------------------
    -- SETTING: Print Updates
    -- ---------------------------------------------------------------------
    local cbPrintUpdate = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbPrintUpdate:SetPoint("TOPLEFT", cbPrintNew, "BOTTOMLEFT", 0, -10)
    cbPrintUpdate.Text:SetText("Chat Message: Kill Update")

    cbPrintUpdate:SetChecked(MobCompendiumDB.settings.printUpdate)
    cbPrintUpdate:SetScript("OnClick", function(self)
        MobCompendiumDB.settings.printUpdate = self:GetChecked()
    end)

    -- ---------------------------------------------------------------------
    -- REGISTER CATEGORY
    -- ---------------------------------------------------------------------
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(panel, "Mob Compendium")
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end