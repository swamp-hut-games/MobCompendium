local _, NS = ...

-- Default Configuration
local defaultSettings = {
    lockWindow = false,
    printNew = true,
    printUpdate = true,
    minimap = {
        hide = false,
        angle = 45
    }
}

function NS.InitSettings()

    if not MobCompendiumDB.settings then
        MobCompendiumDB.settings = CopyTable(defaultSettings)
    else
        for k, v in pairs(defaultSettings) do
            if MobCompendiumDB.settings[k] == nil then
                MobCompendiumDB.settings[k] = v
            end
        end
    end

    local panel = CreateFrame("Frame")
    panel.name = "Mob Compendium"
    
    NS.SettingsPanelFrame = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mob Compendium Settings")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure the behavior of the Mob Compendium.")

    -- ---------------------------------------------------------------------
    -- Lock Window
    -- ---------------------------------------------------------------------
    local cbLock = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbLock:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    cbLock.Text:SetText("Lock Main Window")

    cbLock:SetChecked(MobCompendiumDB.settings.lockWindow)
    cbLock:SetScript("OnClick", function(self)
        MobCompendiumDB.settings.lockWindow = self:GetChecked()
    end)

    -- ---------------------------------------------------------------------
    -- Print New Discoveries
    -- ---------------------------------------------------------------------
    local cbPrintNew = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbPrintNew:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -10)
    cbPrintNew.Text:SetText("Chat Message: New Discovery")

    cbPrintNew:SetChecked(MobCompendiumDB.settings.printNew)
    cbPrintNew:SetScript("OnClick", function(self)
        MobCompendiumDB.settings.printNew = self:GetChecked()
    end)

    -- ---------------------------------------------------------------------
    -- Print Updates
    -- ---------------------------------------------------------------------
    local cbPrintUpdate = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cbPrintUpdate:SetPoint("TOPLEFT", cbPrintNew, "BOTTOMLEFT", 0, -10)
    cbPrintUpdate.Text:SetText("Chat Message: Kill Update")

    cbPrintUpdate:SetChecked(MobCompendiumDB.settings.printUpdate)
    cbPrintUpdate:SetScript("OnClick", function(self)
        MobCompendiumDB.settings.printUpdate = self:GetChecked()
    end)
    
    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, "Mob Compendium")
    NS.SettingsCategory = category
    Settings.RegisterAddOnCategory(category)
end