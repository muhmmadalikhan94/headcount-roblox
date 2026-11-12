-- Game passes, developer products, badges and saved stats.
-- IDs live in Config. Anything left at 0 is simply skipped, so the game runs before you set them up.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Monetization = {}
Monetization.OnPassGranted = nil -- function(player, passName), set by the Director
Monetization.ProductHandlers = {} -- [productName] = function(player) -> granted (bool)

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Headcount_v1")
	end)
	if ok then
		store = result
	end
end

local loaded = {} -- players whose saved data loaded fine (never overwrite data we failed to read)
local grantedReceipts = {} -- PurchaseId -> true for this server

local function passName(passId)
	for name, id in pairs(Config.GamePasses) do
		if id == passId and id ~= 0 then
			return name
		end
	end
	return nil
end

local function productName(productId)
	for name, id in pairs(Config.Products) do
		if id == productId and id ~= 0 then
			return name
		end
	end
	return nil
end

local function grantPass(player, name)
	if player:GetAttribute(name) then
		return
	end
	player:SetAttribute(name, true)
	if Monetization.OnPassGranted then
		Monetization.OnPassGranted(player, name)
	end
end

function Monetization.AwardBadge(player, name)
	local id = Config.Badges[name]
	if not id or id == 0 then
		return
	end
	task.spawn(function()
		pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
	end)
end

local function save(player)
	if not store or not loaded[player] then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	local escapes = stats and stats:FindFirstChild("Escapes")
	if escapes then
		pcall(store.SetAsync, store, "u" .. player.UserId, { Escapes = escapes.Value })
	end
end

function Monetization.SetupPlayer(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local escapes = Instance.new("IntValue")
	escapes.Name = "Escapes"
	escapes.Parent = stats
	local pages = Instance.new("IntValue")
	pages.Name = "Pages"
	pages.Parent = stats
	stats.Parent = player

	for name, id in pairs(Config.GamePasses) do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				grantPass(player, name)
			end
		end
	end
	if store then
		local ok, data = pcall(store.GetAsync, store, "u" .. player.UserId)
		if ok then
			loaded[player] = true
			if type(data) == "table" and type(data.Escapes) == "number" then
				escapes.Value = data.Escapes
			end
		end
	end
	Monetization.AwardBadge(player, "Welcome")
end

function Monetization.AddEscape(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Escapes") then
		stats.Escapes.Value += 1
		task.spawn(save, player)
	end
end

function Monetization.AddPage(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Pages") then
		stats.Pages.Value += 1
	end
end

function Monetization.ResetRoundStats()
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Pages") then
			stats.Pages.Value = 0
		end
	end
end

function Monetization.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passName(passId)
		if purchased and name then
			grantPass(player, name)
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		if grantedReceipts[info.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local name = productName(info.ProductId)
		local handler = name and Monetization.ProductHandlers[name]
		if not player or not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(handler, player)
		if ok and granted then
			grantedReceipts[info.PurchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end)
end

return Monetization
