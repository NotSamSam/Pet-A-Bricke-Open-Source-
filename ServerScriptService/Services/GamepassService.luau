--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Red = require(Packages.Red)

local Gamepasses = require(ReplicatedStorage.Configurations.ShopConfig).Gamepass

local GamepassNet = Red.Server("Gamepass", {"PlayerHasGamepass"})

local DataService = require(script.Parent.DataService)

local GamepassService = {
	playerGamepasses = {},
	_productFoo = {},
}

function GamepassService.OnStart(self: GamepassService)
	Players.PlayerAdded:Connect(function(player: Player)
		self.playerGamepasses[player.UserId] = self:_setTablePlayerGamepasses(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.playerGamepasses[player.UserId] = nil
	end)

	GamepassNet:On("PlayerHasGamepass", function(...): boolean
		return self:PlayerHasGamepass(...)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if wasPurchased then
			self:InsertGamePassToPlayer(player, gamePassId)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		
		local foo = self._productFoo[receiptInfo.ProductId]
		local success, player = pcall(Players.GetPlayerByUserId, Players, receiptInfo.PlayerId)
		if not success or not foo then return Enum.ProductPurchaseDecision.NotProcessedYet end

		local success_foo = pcall(foo, player, receiptInfo.ProductId)
		if not success_foo then return Enum.ProductPurchaseDecision.NotProcessedYet end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

function GamepassService.ConnectOnProductPurchaseFinished(self: GamepassService, devProductId: number, fn: (player: Player) -> ())
	if self._productFoo[devProductId] then
		warn(tostring(devProductId).." product connection was overrided")
	end

	self._productFoo[devProductId] = fn
	return {
		Disconnect = function()
			self._productFoo[devProductId] = nil
		end,
	}
end

function GamepassService.InsertGamePassToPlayer(self: GamepassService, player: Player, gamePassId: number)
	self.playerGamepasses[player.UserId][tostring(gamePassId)] = true
end

function GamepassService.PromptGamepass(self: GamepassService, player: Player, gamePassId: number)
	MarketplaceService:PromptGamePassPurchase(player, gamePassId)
end

function GamepassService.PromptProduct(self: GamepassService, player: Player, productId: number)
	MarketplaceService:PromptProductPurchase(player, productId)
end

function GamepassService.PlayerHasGamepass(self: GamepassService, player: Player, gamePassId: number): boolean
	return self.playerGamepasses[player.UserId] and self.playerGamepasses[player.UserId][tostring(gamePassId)]
end

function GamepassService:_setTablePlayerGamepasses(player: Player): {[string]: boolean}
	local TableGamepassesOwned = {}

	for Name, Id in Gamepasses :: any do
		task.spawn(function()
			self:_setGamepass(player, TableGamepassesOwned, Id)
		end)
	end

	return TableGamepassesOwned
end

function GamepassService:_setGamepass(player: Player, tab: {[string]: boolean}, passId: number)
	local success = pcall(function()
		tab[tostring(passId)] = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) :: boolean
	end)	
	
	

	if not success then
		task.wait(1)
		self:_setGamepass(player, tab, passId)
	end
end



export type GamepassService = typeof(GamepassService)
return GamepassService
