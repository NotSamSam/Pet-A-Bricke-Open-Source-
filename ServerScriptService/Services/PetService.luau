local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Events : Folder = ReplicatedStorage.Events
local PetFunction : RemoteFunction = Events.PetFunction
local BindableEvents : Folder = ServerStorage.BindableEvents
local PetEvent : BindableEvent = BindableEvents.PetEvent

local Utils = ServerStorage.Utils
local DataService = require(script.Parent.DataService)
local DevProductConfig = require(Utils.DevProductConfig)
local GamepassService = require(script.Parent.GamepassService)
local PetModule = require(script.PetModule)
local Red = require(ReplicatedStorage.Packages.Red)

local StealTimeProductId = DevProductConfig.DevProduct.StealTime
local AdminGamepassesId = DevProductConfig.GamePasses.Admin

local PetNet = Red.Server("PetNet", {"FirstCreation", "SetInfos", "RobOnce", "RobAll", "ChangeActions"})

local PetService = {
	PlayersPet = {},
	PlayerTargets = {}
}

function PetService:OnStart()

	GamepassService:ConnectOnProductPurchaseFinished(StealTimeProductId, function(purchasedPlayer: Player)
		local target = self.PlayerTargets[purchasedPlayer]

		if target then
			self:RobbedTimes(purchasedPlayer, target)
			PetNet:FireAll("RobOnce", purchasedPlayer, target)
			self.PlayerTargets[purchasedPlayer] = nil
		end
	end)

	Players.PlayerAdded:Connect(function(plr)
		local connection
		connection = DataService.onDataLoaded:Connect(function(loadedPlayer)
			if loadedPlayer == plr then
				connection:Disconnect()

				self:HandlePlayer(plr)
				self:HandleEvents(plr)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:RemovePet(player)
	end)
end

function PetService:HandlePlayer(player: Player)
	local infosData = DataService:Get(player, "Infos")

	if not infosData.HasCreatedPet then
		PetNet:Fire(player, "FirstCreation")

		PetNet:On("FirstCreation", function(player, newName)
			infosData.Name = newName
			infosData.CreationTime = os.time()
			infosData.HasCreatedPet = true

			self:CreatePet(player, infosData)
			DataService:Set(player, "Infos", infosData)
		end)
	else
		self:CreatePet(player, infosData)
	end
end

function PetService:CreatePet(player, infos)
	local pet = PetModule.new(player, infos)
	self.PlayersPet[player] = pet
end

function PetService:HandleEvents(player: Player)
	PetNet:On("Equip", function(player)
	end)

	PetNet:On("RobOnce", function(player: Player, target: Player)
		if player == target then return end
		if not Players:GetPlayerByUserId(target.UserId) then
			warn("player : " .. target.Name .. " not found in the actual server")
			return
		end

		self.PlayerTargets[player] = target
		self:HandleRobPurchase(player)
	end)

	PetNet:On("RobAll", function(player: Player)
		if GamepassService:PlayerHasGamepass(player, AdminGamepassesId) then
			for _, targetPlayer in Players:GetPlayers() do
			if targetPlayer == player then continue end
			self:RobbedTimes(player, targetPlayer)
			end
			
		else
			GamepassService:PromptGamepass(player, AdminGamepassesId)
		end
	end)
end

function PetService:HandleRobPurchase(player: Player)
	GamepassService:PromptProduct(player, StealTimeProductId)
end

function PetService:RobbedTimes(player: Player, target: Player)
	if player == target then return end

	local playerInfos = DataService:Get(player, "Infos")
	local targetInfos = DataService:Get(target, "Infos")

	playerInfos.AdditionnalTime += (os.time() - targetInfos.CreationTime + targetInfos.AdditionnalTime)
	targetInfos.CreationTime = os.time()
	targetInfos.AdditionnalTime = 0

	DataService:Set(player, "Infos", playerInfos)
	DataService:Set(target, "Infos", targetInfos)

	if self.PlayersPet[player] then
		self.PlayersPet[player]:UpdateInfos(playerInfos)
	end
	if self.PlayersPet[target] then
		self.PlayersPet[target]:UpdateInfos(targetInfos)
	end
end

function PetService:RemovePet(player: Player)
	if self.PlayersPet[player] then
		self.PlayersPet[player]:Destroy()
		self.PlayersPet[player] = nil
	end
end

return PetService
