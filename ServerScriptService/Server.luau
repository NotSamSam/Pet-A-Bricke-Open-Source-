local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Packages = ReplicatedStorage.Packages
local Loader = require(Packages.Loader)

for _, folder in ipairs(StarterGui:GetChildren()) do
	if folder.Name == "SurfaceGuis" then
		continue
	else
		folder.Parent = ReplicatedStorage.Interface.Replicated
	end
end

Loader.SpawnAll(
	Loader.LoadDescendants(script.Services, Loader.MatchesName("Service$")),
	"OnStart"
)

Loader.LoadDescendants(script.Components)
