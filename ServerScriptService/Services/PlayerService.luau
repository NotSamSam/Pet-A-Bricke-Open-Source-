local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerInfo = require(ReplicatedStorage.Configurations.PlayerInfo)

local PlayerService = {}

function PlayerService:OnStart()
	Players.PlayerAdded:Connect(function(player)
		PlayerService.SetInfo(player)
	end)
end

function PlayerService.SetInfo(player)
	for key, value in PlayerInfo do
		local succ, err = pcall(function()
			player:SetAttribute(key, value)
		end)
		if not succ then warn(`error => Key {key} || Value {value} :: {err}`) end
	end
end

return PlayerService
