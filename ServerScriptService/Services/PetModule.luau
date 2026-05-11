local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetsWorkspace = workspace.Pets
local RopesWorkspace = workspace.Ropes
local Assets = ReplicatedStorage.Assets
local Accessory = Assets.Accessory
local Animations = Assets.Animations
local Models = Assets.Models

local CarryAnim: Animation = Animations.CarryAnim
local Interface = ReplicatedStorage.Interface
local Stored = Interface.Stored
local TimeDisplayer = Stored.TimerDisplayer
local PetStored = ReplicatedStorage.PetStored

local ModelToAttachment = require(script.ModelToAttachment)
local PetWelder = require(script.PetWelder)
local ScaleAt = require(script.ScaleAt)

local function formatTime(seconds)
	local days = math.floor(seconds / (24 * 3600))
	local hours = math.floor((seconds % (24 * 3600)) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	return string.format("Age : %02d:%02d:%02d:%02d", days, hours, minutes, secs)
end

local Pet = {}
Pet.__index = Pet

function Pet.new(player: Player, infos: {})
	local self = setmetatable({}, Pet)

	self.owner = player
	self.character = player.Character or player.CharacterAdded:Wait()

	self.name = infos.Name
	self.creationTime = infos.CreationTime
	self.additionnalTime = infos.AdditionnalTime
	self.dataInfos = infos
	self.isEquipped = false
	self.equippedStatus = player:GetAttribute("EquippedStatus")
	self.previousStatus = ""

	self.connections = {}

	-- Model
	self.model = Models.Brick:Clone()
	self.model:SetAttribute("OwnerId", player.UserId)
	self.model.Name = tostring(player.UserId)

	-- Timer UI
	self.timeDisplayer = TimeDisplayer:Clone()
	self.timeDisplayer.Parent = self.model
	self.timeDisplayer.Adornee = self.model

	self:SetGroth()
	self:SetTimer()
	self:SetAttributes()

	self.model.Parent = PetStored

	-- Carry animation
	local carryAnimTrack = self.character:WaitForChild("Humanoid").Animator:LoadAnimation(CarryAnim)

	-- Tool
	local tool = Instance.new("Tool")
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.Name = "Brick"
	tool.Parent = player.Backpack

	--local HB = RunService.Heartbeat:Connect(function()
	--	local scale = self.model:GetScale()
	--	self.model.BrickTorso.CustomPhysicalProperties = PhysicalProperties.new(
	--		math.min(0.5 + scale * 0.2, 1),
	--		math.clamp(0.7 * scale, 0.7, 2),
	--		0.07,
	--		1, 1
	--	)


	--end)

	--table.insert(self.connections, HB)
	self.owner:GetAttributeChangedSignal("EquippedStatus"):Connect(function()
		print('lalaaa')
		if not self.isEquipped or player:GetAttribute("EquippedStatus") == self.equippedStatus then
			return
		end
		print( player:GetAttribute("EquippedStatus"), self.equippedStatus)
		self:Unequip()
		self.previousStatus = self.equippedStatus
		self.equippedStatus = player:GetAttribute("EquippedStatus")
		self:Equip()
	end)

	tool.Equipped:Connect(function()
		self.model.Parent = PetsWorkspace
		;(self.model.PrimaryPart :: BasePart):SetNetworkOwner(player)
		carryAnimTrack:Play()
		self:Equip()
	end)

	tool.Unequipped:Connect(function()
		if  tool.Parent == nil then return end
		print(tool, tool.Parent, tool.Name)
		carryAnimTrack:Stop()
		self:Unequip()
		;(self.model.PrimaryPart :: BasePart):SetNetworkOwner(nil)
		self.model.Parent = PetStored
	end)

	self.petTool = tool

	return self
end

function Pet:Equip()
	if self.isEquipped then return end

	local statusHandler = {
		Walk = function()
			PetWelder.detachPetFromHand(self.character)
			local bricktorso = self.model.PrimaryPart
			
			if not bricktorso.CanCollide then
				bricktorso.CanCollide = true
			end
			
			if self.previousStatus ~= "Carry" then
				local pivot = self.character:GetPivot()
				local offset = Vector3.new(-self.model:GetExtentsSize().X, 0, 0)
				local targetPos = pivot.Position + (pivot.LookVector * offset.X/2)
				self.model:PivotTo(CFrame.new(targetPos, targetPos + pivot.LookVector))
			end

			local att1 = self.model.BrickTorso.FaceFrontAttachment
			local att2 = self.character["Right Arm"].RightGripAttachment
			
			local currentScale = self.model:GetScale()
			local extraSlack = math.clamp(currentScale * 2, 5, 15)
			
			local rope = Instance.new("RopeConstraint")
			rope.Name = self.owner.UserId
			rope.Attachment0 = att2
			rope.Attachment1 = att1
			rope.Length = (att1.WorldPosition - att2.WorldPosition).Magnitude + extraSlack
			rope.Visible = true
			rope.Thickness = 0.05
			rope.Parent = RopesWorkspace
		end,

		Carry = function()
			local bricktorso = self.model.PrimaryPart
			if bricktorso.CanCollide then
				bricktorso.CanCollide = false
			end
			PetWelder.attachPetToHand(self.character, self.model, self.model:GetScale())

			self.petConnection = RunService.Heartbeat:Connect(function()
				PetWelder.updateGrip(self.model:FindFirstChild("PetWeld"))
			end)
			table.insert(self.connections, self.petConnection)
		end
	}

	local handler = statusHandler[self.equippedStatus]
	if handler then
		handler()
	else
		warn("Unknown equipped status:", self.equippedStatus)
		return
	end

	self.isEquipped = true
end

function Pet:Unequip()
	if not self.isEquipped then return end

	if self.equippedStatus == "Carry" then
		if self.petConnection then
			self.petConnection:Disconnect()
		end
		PetWelder.detachPetFromHand(self.character)
	else
		local rope = RopesWorkspace:FindFirstChild(self.owner.UserId)

		if 	rope then
			rope:Destroy()
		end
	end

	self.isEquipped = false
end

function Pet:UpdateInfos(infos)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	self.creationTime = infos.CreationTime
	self.additionnalTime = infos.AdditionnalTime
	self.dataInfos = infos

	self:SetTimer()
end

function Pet:UpdateAttributs()
	self.name = self.dataInfos.Name
	self.additionnalTime = self.dataInfos.AdditionnalTime
end

function Pet:GetOwner()
	return self.owner
end

function Pet:SetGroth()
	if table.find(self.connections, self.grothConnection) then return end

	local lastScale = 0 
	local SCALE_THRESHOLD = 0.05 

	local BASE_DENSITY = 0.05 

	local BASE_FRICTION = 0.2 

	self.grothConnection = RunService.Heartbeat:Connect(function()
		local age = os.time() - self.creationTime + self.additionnalTime
		local currentScale = ScaleAt(age)

		local difference = math.abs(currentScale - lastScale)

		if difference >= SCALE_THRESHOLD then
			self.model:ScaleTo(currentScale)
			lastScale = currentScale 

			local mainPart = self.model:FindFirstChild("BrickTorso")

			if mainPart then
				local newDensity = BASE_DENSITY / (currentScale * currentScale)

				mainPart.CustomPhysicalProperties = PhysicalProperties.new(newDensity, BASE_FRICTION, 0, 100, 100)
			end
		end
	end)

	table.insert(self.connections, self.grothConnection)
end
function Pet:SetTimer()
	if table.find(self.connections, self.timerConnection) then return end

	local textUi = self.timeDisplayer.TextLabel

	self.timerConnection = RunService.Heartbeat:Connect(function()
		local seconds = os.time() - self.creationTime + self.additionnalTime
		textUi.Text = formatTime(seconds)
	end)
	table.insert(self.connections, self.timerConnection)
end

function Pet:SetParent(parent: Instance)
	self.model.Parent = parent
end

function Pet:SetAttributes()
	local defaultAttributes = {
		Hat = "Cone Hat",
		Face = "Basic Eyes",
		Color = "Grey",
	}

	self.currentCosmetics = {}

	for name, default in pairs(defaultAttributes) do
		self.model:SetAttribute(name, default)
		self.currentCosmetics[name] = default

		local connection = self.model:GetAttributeChangedSignal(name):Connect(function()
			self:_onAttributeChanged(name)
		end)
		table.insert(self.connections, connection)
	end

	for name, _ in pairs(defaultAttributes) do
		self:_onAttributeChanged(name)
	end
end


function Pet:_onAttributeChanged(attributeName)
	local cosmeticFolders = {
		Hat = Accessory.Hats,
		Face = Accessory.Faces,
		Color = Accessory.Colors
	}

	if attributeName == "Hat" or attributeName == "Face" then
		local cosmeticName = self.model:GetAttribute(attributeName)
		local parentFolder = cosmeticFolders[attributeName]

		local previous = self.currentCosmetics[attributeName]
		if previous and self.model:FindFirstChild(previous) then
			self.model[previous]:Destroy()
		end

		if cosmeticName == "None" then
			self.currentCosmetics[attributeName] = nil
			return
		end

		local cosmeticTemplate = parentFolder:FindFirstChild(cosmeticName)
		if not cosmeticTemplate then
			warn(cosmeticName, "not found in", attributeName, "folder")
			return
		end

		local cosmetic :Model= cosmeticTemplate:Clone()
		cosmetic.Parent = self.model
		cosmetic:ScaleTo(self.model:GetScale())
		ModelToAttachment(self.model, cosmetic, attributeName)
		self.currentCosmetics[attributeName] = cosmetic.Name

	else
		local colorName = self.model:GetAttribute(attributeName)
		local parentFolder = cosmeticFolders[attributeName]
		local colorTemplate = parentFolder:FindFirstChild(colorName)

		if not colorTemplate then
			warn(colorName, "not found in", attributeName, "folder")
			return
		end

		self.model.BrickTorso.Color = colorTemplate.Value
		self.currentCosmetics[attributeName] = colorName
	end
end

function Pet:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end

	if self.timerConnection then
		self.timerConnection:Disconnect()
	end

	self.model:Destroy()
	self.petTool:Destroy()

	table.clear(self)
	setmetatable(self, nil)
end

return Pet
