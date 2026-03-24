function WarbandTax_OnLoad(self)
    WT_BankOpen = false
    WT_IsTwinkMail = false
    WT_MailIncome = 0

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("QUEST_TURNED_IN")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    self:RegisterEvent("MAIL_SEND_SUCCESS")

    SLASH_WT1 = "/WT"
    SlashCmdList["WT"] = function(msg)
        if msg == "reset" then
            WarbandTaxDue = 0
            print("|cffFF7C0AWT|r: Tax due reset!")

        elseif msg == "quiet" then
            WarbandQuietMode = 1
            print("|cffFF7C0AWT|r: Quiet mode enabled.")

        elseif msg == "verbose" then
            WarbandQuietMode = 0
            print("|cffFF7C0AWT|r: Verbose mode enabled.")

        elseif msg == "help" then
            print("|cffFF7C0AWT|r: Version: "..C_AddOns.GetAddOnMetadata("WarbandTax","Version"))
            print("Set the tax rate by /wt tax 10")
            print("Standard tax is 50%.")
            print("Income from loot, quest rewards & auction house will be taxed.")
            print("Tax is deposited automatically when opening the Warband Bank.")
            print("Commands:")
            print("/WT help")
            print("/WT reset")
            print("/WT quiet")
            print("/WT verbose")
            print("/WT tax 10")

		elseif msg:find("tax") then
            local num = tonumber(msg:match("(%d+)"))
            if num then
                WarbandTaxPercentage = num
                print(format("|cffFF7C0AWT|r: Tax changed to %d%%", num))
            end

        else
            print("|cffFF7C0AWT|r: Version: "..C_AddOns.GetAddOnMetadata("WarbandTax","Version"))
            print(format("|cffFF7C0AWT|r: Current Tax Rate: %d%%", WarbandTaxPercentage))
            --print("|cffFF7C0AWT|r: Current Tax Due: " .. C_CurrencyInfo.GetCoinText(WarbandTaxDue))
			local due = WarbandTaxDue or 0
			local dueText = (due > 0) and C_CurrencyInfo.GetCoinText(due) or "|cff00FF00Keine|r"
			print("|cffFF7C0AWT|r: Current Tax Due: " .. dueText)
            print("|cffFF7C0AWT|r: Total Tax Paid: " .. C_CurrencyInfo.GetCoinText(WarbandTaxToDate))
        end
    end

    -- Auction House tax via mail
    local origTakeInboxMoney = TakeInboxMoney
    TakeInboxMoney = function(index)
        local _, _, sender, subject, money, CODAmount = GetInboxHeaderInfo(index)

        -- no money → no tax
        if not money or money <= 0 then
            WT_MailIncome = 0
            WT_IsTwinkMail = false
            return origTakeInboxMoney(index)
        end

        local invoice = GetInboxInvoiceInfo(index)
        local invoiceType = invoice and invoice.invoiceType

        -- invoiceType 2 = AH Seller, 3 = COD
        if invoiceType == 2 or invoiceType == 3 then
            WT_MailIncome = money
            WT_IsTwinkMail = false
        else
            -- normal mail (Twink, NPC, refund)
            WT_MailIncome = 0
            WT_IsTwinkMail = true
        end

        return origTakeInboxMoney(index)
    end
end

---------------------------------------------------------
-- TAX LOGIC
---------------------------------------------------------

local function WT_TaxFromDelta(newMoney)
    if newMoney > WTCurrentMoney then
        local gained = newMoney - WTCurrentMoney
        local taxMoney = gained * WarbandTaxPercentage / 100
        if taxMoney > 0 then
            WarbandTaxDue = WarbandTaxDue + taxMoney
            if WarbandQuietMode == 0 then
                print(format("|cffFF7C0AWT|r: Taxed income: %s", C_CurrencyInfo.GetCoinText(taxMoney)))
            end
        end
    end
    WTCurrentMoney = newMoney
end

local function WT_TaxFromLootMoney(lootMoney)
    if lootMoney and lootMoney > 0 then
        local taxMoney = lootMoney * WarbandTaxPercentage / 100
        if taxMoney > 0 then
            WarbandTaxDue = WarbandTaxDue + taxMoney
            if WarbandQuietMode == 0 then
                print(format("|cffFF7C0AWT|r: Taxed loot: %s", C_CurrencyInfo.GetCoinText(taxMoney)))
            end
        end
    end
end

local function WT_TaxFromQuestMoney(moneyReward)
    if moneyReward and moneyReward > 0 then
        local taxMoney = moneyReward * WarbandTaxPercentage / 100
        if taxMoney > 0 then
            WarbandTaxDue = WarbandTaxDue + taxMoney
            if WarbandQuietMode == 0 then
                print(format("|cffFF7C0AWT|r: Taxed quest reward: %s", C_CurrencyInfo.GetCoinText(taxMoney)))
            end
        end
    end
end

---------------------------------------------------------
-- PAY TAX (BankType.Account = 2)
---------------------------------------------------------

local function WT_PayTax(bankType)
    if bankType ~= 2 then return end  -- Warband-Bank your Client

    local toPayTax = 0
    if GetMoney() > WarbandTaxDue then
        toPayTax = WarbandTaxDue
    end

    if toPayTax > 0 then
        C_Bank.DepositMoney(2, toPayTax)
        WarbandTaxDue = WarbandTaxDue - toPayTax
        WarbandTaxToDate = WarbandTaxToDate + toPayTax

        if WarbandQuietMode == 0 then
            print(format("|cffFF7C0AWT|r: Tax paid: %s", C_CurrencyInfo.GetCoinText(toPayTax)))
        end
    end
end

---------------------------------------------------------
-- MAIN EVENT HANDLER
---------------------------------------------------------

function WarbandTax_OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "WarbandTax" then
            WarbandTaxDue = WarbandTaxDue or 0
            WarbandTaxToDate = WarbandTaxToDate or 0
            WarbandTaxPercentage = WarbandTaxPercentage or 50
            WarbandQuietMode = WarbandQuietMode or 0
            WTCurrentMoney = GetMoney()

            print("|cffFF7C0AWarband Tax|r loaded. /WT help - Test Post")
        end

    elseif event == "PLAYER_MONEY" then
        local newMoney = GetMoney()

        if WT_MailSent then
            WT_MailSent = false
            WTCurrentMoney = newMoney
            return
        end

        if WT_BankOpen then
            WTCurrentMoney = newMoney
            return
        end
        
        if newMoney < WTCurrentMoney then
            WTCurrentMoney = newMoney
            return
        end

        if newMoney > WTCurrentMoney then
            WT_TaxFromDelta(newMoney)
            WTCurrentMoney = newMoney
            return
        end

        WTCurrentMoney = newMoney

    elseif event == "LOOT_OPENED" then
        local lootMoney = 0
        for i = 1, GetNumLootItems() do
            if GetLootSlotType(i) == LOOT_SLOT_MONEY then
                lootMoney = lootMoney + select(3, GetLootSlotInfo(i))
            end
        end
        WT_TaxFromLootMoney(lootMoney)

    elseif event == "QUEST_TURNED_IN" then
        local questID, xpReward, moneyReward = ...
        WT_TaxFromQuestMoney(moneyReward)

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...

        -- 68 = Konvergenz-Bank (always Warband) | 8 = NPC-Bank (can be Warband)
        if interactionType == 68 or interactionType == 8 then
            WT_BankOpen = true
            WT_PayTax(2)
            return
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        WT_BankOpen = false

    elseif event == "MAIL_SEND_SUCCESS" then
        WT_MailSent = true
    end
end