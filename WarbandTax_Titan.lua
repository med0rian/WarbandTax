-- Titan Panel Plugin with LibDataBroker for WarbandTax

local LDB = LibStub("LibDataBroker-1.1");
if not LDB then return end

local dataObject = LDB:NewDataObject("WarbandTaxTitan", {
    type = "data source",
    label = "Warband Tax",
    text = "WT",
    icon = "Interface\\MoneyFrame\\UI-GoldIcon",
})

local function GetColorbyRate(rate)
    if rate >= 0 and rate < 25 then
        return "|cff00FF00"; -- Grün
    elseif rate >= 25 and rate < 50 then
        return "|cffFFFF00"; -- Gelb
    elseif rate >= 50 and rate < 75 then
        return "|cffFFA500"; -- Orange
    elseif rate >= 75 and rate < 100 then
        return "|cffFF4500"; -- Rot-Orange
    elseif rate >= 100 then
        return "|cffFF0000"; -- Rot
    end
end

local function GetColoredCoinText(amount)
    local gold = math.floor(amount / 10000);
    local silver = math.floor((amount % 10000) / 100);
    local copper = amount % 100;

    local parts = {};
    if gold > 0 then
        table.insert(parts, string.format("|cffFFD700%dg|r", gold)); -- Gold in Gelb
    end
    if silver > 0 then
        table.insert(parts, string.format("|cffC0C0C0%ds|r", silver)); -- Silber in Silber
    end
    if copper > 0 then
        table.insert(parts, string.format("|cffB87333%dc|r", copper)); -- Kupfer in Kupfer
    end
    return table.concat(parts, " ");
end

local function UpdateText()
    local due = WarbandTaxDue or 0
    local dueText = (due > 0) and GetColoredCoinText(due) or "|cff00FF00Keine|r"
    local rate = WarbandTaxPercentage or 0
    local color = GetColorbyRate(rate)
    dataObject.text = string.format("%s%d%%|r | %s", color, rate, dueText)
end

function dataObject:OnTooltipShow()
    self:AddLine("|cffffff00Warband Tax|r")
    self:AddLine(" ")
    self:AddLine("Aktuelle Steuerrate: " .. (WarbandTaxPercentage or 0) .. "%")
    if WarbandTaxDue > 0 then
        self:AddLine("Offene Steuer: " .. C_CurrencyInfo.GetCoinText(WarbandTaxDue or 0))
    else
        self:AddLine("Offene Steuer: |cff00FF00Keine|r")
    end
end

function dataObject:OnClick(button)
    local due = WarbandTaxDue or 0
    local dueText = (due > 0) and GetColoredCoinText(due) or "|cff00FF00Keine|r";
    if button == "LeftButton" then
        print("|cffFF7C0AWT|r: Offene Steuer: " .. dueText);
    end
end

-- UpdateText
local f = CreateFrame("Frame");
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "WarbandTax" then
        UpdateText();
    else
        UpdateText();
    end
end);
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("PLAYER_MONEY");
f:RegisterEvent("QUEST_TURNED_IN");
f:RegisterEvent("LOOT_OPENED");
f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW");

--Initial update
UpdateText()