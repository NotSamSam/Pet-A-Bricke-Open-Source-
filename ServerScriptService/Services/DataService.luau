--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Template = require(script.Template)
local Signal = require(script.MainModule.Signal)
local DataStoreModule = require(script.MainModule)

local shownData = Template.shownData
local template = Template.template

local id = "Player_" .. (if RunService:IsStudio() then "Studio4" else "Client")
local storage = DataStoreModule.GetProfileStore(id, template)

local NetworkFolder = script.DataStoreNetwork:Clone()
NetworkFolder.Parent = ReplicatedStorage

local function setupLeaderstats(player: Player, dataStore)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	for dataName: string, value: number in dataStore.Data do
		if table.find(shownData, dataName) == nil then continue end

		local intValue = Instance.new("IntValue")
		intValue.Name = dataName
		intValue.Value = value or template[dataName]
		intValue.Parent = leaderstats
	end
end

local Profiles = {}
local signals = {}
local module = {
	onDataLoaded = Signal.new();

	joinMessage = "Successfully loaded %s's data.";
	leaveMessage = "Successfully saved %s's data.";
	notification = false;
}

function module:IsPlayerLoaded(player)
	return Profiles[player] ~= nil
end

function module:CreateSignal(player: Player, dataName: string)
	local instance = nil
	if signals[player.Name] == nil then 
		signals[player.Name] = {}
	end
	if signals[player.Name][dataName] == nil then
		signals[player.Name][dataName] = Signal.new()
	end

	return { changed = signals[player.Name][dataName] }
end

function module:Get(player: Player, dataName: string)
	local dataStore = Profiles[player]
	if dataStore == nil then return end

	local split = dataName:split(">")
	local data = dataStore.Data[split[1]]
	if #split < 1 then return data end
	for i=2, #split do
		data = data[split[i]]
	end

	return data
end

function module:Set(player: Player, dataName: string, newData: any)
	local dataStore = Profiles[player]
	if dataStore == nil then return end
	
	local leaderstats: Folder? = player:FindFirstChild("leaderstats")
	if leaderstats == nil or leaderstats:IsA("Folder") ~= true then return end
	
	local intValue: Instance? = leaderstats:FindFirstChild(dataName)
	if (intValue) and intValue:IsA("IntValue") then 
		intValue.Value = newData
	end

	local split = dataName:split(">")
	local data = dataStore.Data
	if #split > 1 then
		for i=1, #split-1 do
			data = data[split[i]]
		end
	end

	data[split[#split]] = newData
	if signals[player.Name] == nil then
		signals[player.Name] = {}
	end

	if signals[player.Name][dataName] == nil then return end
	local oldData = module:Get(player, dataName)
	signals[player.Name][dataName]:Fire(newData)
	NetworkFolder:WaitForChild("ClientSignals"):FireClient(player, dataName, oldData, newData)
end

function module:Update(player: Player, dataName: string, updateData: (arg: number | boolean | {}) -> ())
	local data = module:Get(player, dataName)
	module:Set(player, dataName, updateData(data))
end

local function onPlayerAdded(player: Player)
	local dataStore = storage:LoadProfileAsync("Player_" .. player.UserId)
	if dataStore == nil then player:Kick() end
	
	dataStore:Reconcile()
	dataStore:AddUserId(player.UserId)
	
	dataStore:ListenToRelease(function()
		Profiles[player] = nil
		player:Kick()
	end)

	if player:IsDescendantOf(Players) then
		Profiles[player] = dataStore
	else
		dataStore:Release()
	end
	setupLeaderstats(player, dataStore)
	
	NetworkFolder.DataLoaded:FireClient(player)
	module.onDataLoaded:Fire(player)
	local joinMessage1 = module.joinMessage:gsub("@", player.Name):format(player.Name)
	print(joinMessage1)
	
	if signals[player.Name] == nil then
		signals[player.Name] = {}
	end
end

function onPlayerRemoving(player: Player)
	local dataStore = Profiles[player]
	if dataStore ~= nil then
		dataStore:Release()
		local leaveMessage = module.leaveMessage:gsub("@", player.Name):format(player.Name)
		print(leaveMessage)
	end

	if signals[player.Name] == nil then return end
	for _, signal: Signal.Signal in signals[player.Name] do
		signal:DisconnectAll()
	end
	
	signals[player.Name] = nil
end

function module:OnStart()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player: Player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

NetworkFolder.GetData.OnServerInvoke = function(player: Player, dataName: string)
	return module:Get(player, dataName)
end

return module
