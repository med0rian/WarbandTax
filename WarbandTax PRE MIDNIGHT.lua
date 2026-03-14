function WarbandTax_OnLoad(self)
	WTWatchForMailInboxUpdate = 0;
	--[[ ADDON_APOCOLYPSE 12.0.0
	self:RegisterEvent("CHAT_MSG_MONEY");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	]]
	--NEW
	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("LOOT_OPENED");
	self:RegisterEvent("QUEST_TURNED_IN");
	--/NEW
	self:RegisterEvent("MERCHANT_SHOW");
	self:RegisterEvent("MERCHANT_CLOSED");
	--[[ ADDON_APOCOLYPSE 12.0.0
	self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED");
	self:RegisterEvent("BANKFRAME_OPENED");
	]]
	--NEW
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW");
	--/NEW
	self:RegisterEvent("ADDON_LOADED");
	SLASH_WT1 = "/WT";
	SlashCmdList["WT"] = function(msg, editBox)
		if msg == "reset" then
			print("|cffFF7C0AWT|r: Tax due reset!");
			WarbandTaxDue = 0;
		elseif msg == "quiet" then
			WarbandQuietMode = 1;
			print("|cffFF7C0AWT|r: Quiet mode enabled.");
		elseif msg == "verbose" then
			WarbandQuietMode = 0;
			print("|cffFF7C0AWT|r: Verbose mode enabled.");
		elseif msg == "help" then
			print("|cffFF7C0AWT|r: Version: "..C_AddOns.GetAddOnMetadata("WarbandTax","Version")); 
			print("Set the tax rate by |cffFF0000 /wt tax 10|r (or whetever percentage you want)");
			print("Standard tax is 50%.");
			print("Income from loot, quest rewards & auction house will be taxed. Individual player transactions are not taxed. Any tax due will be automatically deposited (assuming the member has funds) next time the character opens the warband bank.");
			print("Slash commands usable:");
			print("|cffFF7C0A/WT help|r -- prints this message");
			print("|cffFF7C0A/WT reset|r -- reset tax due");
			print("|cffFF7C0A/WT quiet|r -- turn on quiet(ish) mode, user won't get notified when amounts are taxed");
			print("|cffFF7C0A/WT verbose|r -- turn on verbose mode (default), user will be notified of amounts taxed");
			print("|cffFF7C0A/WT tax 10|r (or whetever percentage you want) -- defines the percentage of gold that will be applied to make up the amount to be deposited in your warband bank.");
			print("|cffFF7C0A/WT|r -- display version, current tax due and total tax paid");
		elseif msg:startswith('tax') then
			local command, rest = msg:match("[0-9]*\.[0-9]+");
			WarbandTaxPercentage = command;
			print(format("|cffFF7C0AWT|r: Tax changed to %d%%", WarbandTaxPercentage));		
		else
			print("|cffFF7C0AWT|r: Version: "..C_AddOns.GetAddOnMetadata("WarbandTax","Version")); 
			print(format("|cffFF7C0AWT|r: Current Tax Rate: %d%%", WarbandTaxPercentage)); 
			print("|cffFF7C0AWT|r: Current Tax Due: "..GetCoinText(WarbandTaxDue)); 
			print("|cffFF7C0AWT|r: Total Tax Paid: "..GetCoinText(WarbandTaxToDate));
		end
	end
	local origTakeInboxMoney = TakeInboxMoney;
	TakeInboxMoney = function(...)
		local index = ...;
		local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(index);
		if invoiceType == "seller" then
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, 
				textCreated, canReply, isGM = GetInboxHeaderInfo(index);
			if money > 0 then
				local taxMoney = money*WarbandTaxPercentage/100;
				if taxMoney > 0 then
					if WarbandQuietMode == 0 then
						print(format("|cffFF7C0AWT|r: Taxed auction house tax: %s", GetCoinText(taxMoney)));
					end
					WarbandTaxDue = WarbandTaxDue + taxMoney;
				end
			end
		end
		origTakeInboxMoney(...);
	end
end

string.startswith = function(self, str) 
    return self:find('^' .. str) ~= nil
end

local function WT_UpdateTaxAfterTransaction()
	local newMoney = GetMoney();
	if newMoney > WTCurrentMoney then
		local taxMoney = (newMoney - WTCurrentMoney)*WarbandTaxPercentage/100;
		WarbandTaxDue = WarbandTaxDue + taxMoney;
		if taxMoney>0 then
			if WarbandQuietMode == 0 then
				print(format("|cffFF7C0AWT|r: Taxed sales: %s", GetCoinText(taxMoney)));
			end
		end
		-- prevent double taxation in case events fire twice
		WTCurrentMoney = newMoney;
	end
end

local function WT_UpdateTaxAfterQuestOrLoot(chatmsg)
	-- parse the message
	local gold = tonumber(chatmsg:match("(%d+)%s" .. WTGoldStr)) or 0;
	local silver = tonumber(chatmsg:match("(%d+)%s" .. WTSilverStr)) or 0;
	local copper = tonumber(chatmsg:match("(%d+)%s" .. WTCopperStr)) or 0;
	local newMoney = gold * COPPER_PER_GOLD + silver * COPPER_PER_SILVER + copper;
	local taxMoney = newMoney*WarbandTaxPercentage/100;
	if taxMoney > 0 then
		if WarbandQuietMode == 0 then
			print(format("|cffFF7C0AWT|r: Taxed loot/quest: %s", GetCoinText(taxMoney)));
		end
		WarbandTaxDue = WarbandTaxDue + taxMoney;
	end
end

local function WT_UpdateTaxAfterOpenMail(chatmsg) 
	local gold = tonumber(chatmsg:match("(%d+)%s" .. WTGoldStr)) or 0;
	local silver = tonumber(chatmsg:match("(%d+)%s" .. WTSilverStr)) or 0;
	local copper = tonumber(chatmsg:match("(%d+)%s" .. WTCopperStr)) or 0;
	if money > 0 then
		newMoney = TakeInboxMoney(index);
		local taxMoney = newMoney * WarbandTaxPercentage/100;
		WarbandTaxDue = WarbandTaxDue + taxMoney;
		if taxMoney>0 then
			if WarbandQuietMode == 0 then
				print(format("|cffFF7C0AWT|r: Taxed sales: %s", GetCoinText(taxMoney)));
			end
		end
	else
		return WT_UpdateTaxAfterOpenMail(index - 1);
	end
end

local function WT_PayTax(bankType)
	local toPayTax = 0;
	-- can we even pay the whole amount of the tax?
	if GetMoney() > WarbandTaxDue then
		toPayTax = WarbandTaxDue;
	end
	if toPayTax > 0 then
		-- DepositGuildBankMoney(toPayTax);
		C_Bank.DepositMoney(bankType, toPayTax);
		--C_Bank.DepositMoney(2, toPayTax); Warband Bank type 2
		WarbandTaxDue = WarbandTaxDue - toPayTax;
		WarbandTaxToDate = WarbandTaxToDate + toPayTax;
		if WarbandQuietMode == 0 then
			print(format("|cffFF7C0AWT|r: Tax paid: %s", GetCoinText(toPayTax)));
			if WarbandTaxDue == 0 then
				print(format("|cffFF7C0AWT|r: All taxes due have been paid."));
			else
				print(format("|cffFF7C0AWT|r: Unable to pay all tax, still missing %s", GetCoinText(WarbandTaxDue)));
			end
		end
	end
end

function WarbandTax_OnEvent(self, event, ...)
	local arg1, arg2 = ...;
	if event == "ADDON_LOADED" then
		if arg1 == "WarbandTax" then
			-- first time we load the addon, WarbandTaxDue/WarbandTaxPercentage will be nil
			if WarbandTaxDue == nil then
				WarbandTaxDue = 100;
			end
			if WarbandTaxToDate == nil then
				WarbandTaxToDate = 0;
			end
			if WarbandTaxPercentage == nil then
				WarbandTaxPercentage = 50;
			end
			if WarbandQuietMode == nil then
				WarbandQuietMode = 0;
			end
			WTCurrentMoney = GetMoney();
			-- Figure out what GOLD, SILVER, and COPPER are in the client language 
			WTGoldStr = strmatch(format(GOLD_AMOUNT, 20), "%d+%s(.+)") -- This will return what's in the brackets, which on enEU would be "Gold"
			WTSilverStr = strmatch(format(SILVER_AMOUNT, 20), "%d+%s(.+)")
			WTCopperStr = strmatch(format(COPPER_AMOUNT, 20), "%d+%s(.+)")
			-- print welcome message
			print("|cffFF7C0AWarband Tax|r version "..C_AddOns.GetAddOnMetadata("WarbandTax","Version")..". Type |cffFF7C0A/WT help|r for help."); 
		end
	elseif event == "MERCHANT_SHOW" then
		WTCurrentMoney = GetMoney();
	elseif event == "MERCHANT_CLOSED" then
		WT_UpdateTaxAfterTransaction();
	elseif event == "LOOT_OPENED" or event == "QUEST_TURNED_IN" then
		WT_UpdateTaxAfterQuestOrLoot(arg1);
	elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
		WT_PayTax(2);
	elseif event == "BANKFRAME_OPENED" then
		WT_PayTax(2);
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
		local interactionType = ...;
		if interactionType == Enum.PlayerInteractionType.WarbandBanker then
			WT_PayTax(Enum.BankType.Warband);
		end
	elseif event == "PLAYER_MONEY" then
		local newMoney = GetMoney();
		if newMoney > WTCurrentMoney then
			local gained = newMoney - WTCurrentMoney;
			local tax = gained * WarbandTaxPercentage / 100;
			if tax > 0 then
				WarbandTaxDue = WarbandTaxDue + tax;
				if WarbandQuietMode == 0 then
					print(format("|cffFF7C0AWT|r: Taxed income: %s", GetCoinText(tax)));
				end
			end
		end
	end
end