--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WorldController = {}
WorldController.__index = WorldController

local COLORS = {
	Ink = Color3.fromRGB(17, 24, 32),
	Metal = Color3.fromRGB(50, 62, 70),
	Cyan = Color3.fromRGB(71, 230, 210),
	Toxic = Color3.fromRGB(178, 255, 43),
	Purple = Color3.fromRGB(174, 91, 255),
}

local function part(parent, name, size, cframe, color, material)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = false
	item.CanQuery = false
	item.CanTouch = false
	item.CastShadow = false
	item.Parent = parent
	return item
end

local function labelOn(parent, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 0.2
	textLabel.BackgroundColor3 = COLORS.Ink
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel
end

local function makeBlob(parent, mutant, at)
	local model = Instance.new("Model")
	model.Name = tostring(mutant.Id)
	model:SetAttribute("MutantId", mutant.Id)
	local toxic = mutant.Type == "ToxicBlob"
	local bodyColor = if toxic then COLORS.Toxic else COLORS.Cyan
	local bodySize = if toxic then Vector3.new(3.5, 2.8, 3.5) else Vector3.new(3.1, 2.5, 3.1)
	local body = part(model, "Body", bodySize, at * CFrame.new(0, 1.5, 0), bodyColor, Enum.Material.Neon)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	for _, x in { -0.58, 0.58 } do
		local eye = part(
			model,
			"Eye",
			Vector3.new(0.5, 0.65, 0.28),
			at * CFrame.new(x, 1.85, -1.42),
			Color3.fromRGB(236, 255, 250),
			Enum.Material.Neon
		)
		eye.Shape = Enum.PartType.Ball
		local pupil = part(
			model,
			"Pupil",
			Vector3.new(0.2, 0.28, 0.15),
			at * CFrame.new(x, 1.82, -1.64),
			COLORS.Ink,
			Enum.Material.SmoothPlastic
		)
		pupil.Shape = Enum.PartType.Ball
	end

	if toxic then
		for index = 0, 5 do
			local angle = (math.pi * 2 / 6) * index
			local spikeCFrame = at
				* CFrame.new(math.cos(angle) * 1.55, 2.6, math.sin(angle) * 1.55)
				* CFrame.Angles(math.cos(angle) * 0.35, 0, -math.sin(angle) * 0.35)
			local spike = part(
				model,
				"ToxicSpike",
				Vector3.new(0.35, 1.4, 0.35),
				spikeCFrame,
				COLORS.Purple,
				Enum.Material.Neon
			)
			spike.Shape = Enum.PartType.Cylinder
		end
	end

	local displayName = if toxic then "TOXIC BLOB" else "BLOB"
	labelOn(
		body,
		string.format("%s  •  Lv.%s", displayName, tostring(mutant.Level or 1)),
		Vector3.new(0, 2.6, 0)
	)
	model.Parent = parent
	return model
end

local function makeDummy(parent)
	local model = Instance.new("Model")
	model.Name = "CombatDummy"
	local root = part(
		model,
		"Root",
		Vector3.new(1.8, 3.6, 1.4),
		CFrame.new(3, 2.2, 8),
		Color3.fromRGB(224, 112, 70),
		Enum.Material.Wood
	)
	model.PrimaryPart = root
	local head = part(
		model,
		"Head",
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(3, 4.8, 8),
		Color3.fromRGB(238, 153, 81),
		Enum.Material.Wood
	)
	head.Shape = Enum.PartType.Ball
	for _, x in { -1.3, 1.3 } do
		part(
			model,
			"Arm",
			Vector3.new(0.65, 3, 0.65),
			CFrame.new(3 + x, 2.4, 8),
			Color3.fromRGB(117, 75, 53),
			Enum.Material.Wood
		)
	end
	labelOn(head, "TRAINING DUMMY", Vector3.new(0, 1.8, 0))
	model.Parent = parent
	return model
end

function WorldController.new()
	local self = setmetatable({}, WorldController)
	self._root = nil
	self._display = nil
	self._battleFolder = nil
	self._battle = false
	self._renderConnection = nil
	self._camera = nil
	self._previousCameraType = nil
	self._previousCameraSubject = nil
	self._previousCameraCFrame = nil
	return self
end

function WorldController:Start()
	local root = Instance.new("Folder")
	root.Name = "MutantLabClient_" .. tostring(Players.LocalPlayer.UserId)
	root.Parent = workspace
	self._root = root

	local architecture = Instance.new("Folder")
	architecture.Name = "Architecture"
	architecture.Parent = root
	part(
		architecture,
		"BackWall",
		Vector3.new(32, 12, 1),
		CFrame.new(0, 6, 14),
		COLORS.Ink,
		Enum.Material.Metal
	)
	part(
		architecture,
		"LightStrip",
		Vector3.new(25, 0.35, 0.25),
		CFrame.new(0, 9, 13.42),
		COLORS.Cyan,
		Enum.Material.Neon
	)
	part(
		architecture,
		"Bench",
		Vector3.new(20, 1, 4),
		CFrame.new(-3, 1, 8),
		COLORS.Metal,
		Enum.Material.Metal
	)
	for index = 1, 6 do
		local x = -13 + (index - 1) * 5.1
		part(
			architecture,
			"Pad",
			Vector3.new(4.2, 0.35, 4.2),
			CFrame.new(x, 0.3, 3),
			Color3.fromRGB(34, 46, 54),
			Enum.Material.Metal
		)
		part(
			architecture,
			"PadGlow",
			Vector3.new(3.5, 0.12, 3.5),
			CFrame.new(x, 0.51, 3),
			if index % 2 == 0 then COLORS.Purple else COLORS.Cyan,
			Enum.Material.Neon
		)
	end
	for _, x in { -14, 13 } do
		local tube = part(
			architecture,
			"SpecimenTube",
			Vector3.new(3, 7, 3),
			CFrame.new(x, 4.1, 10.5),
			Color3.fromRGB(74, 147, 145),
			Enum.Material.Glass
		)
		tube.Transparency = 0.45
		part(
			architecture,
			"TubeTop",
			Vector3.new(3.4, 0.5, 3.4),
			CFrame.new(x, 7.8, 10.5),
			COLORS.Metal,
			Enum.Material.Metal
		)
		part(
			architecture,
			"TubeBase",
			Vector3.new(3.4, 0.5, 3.4),
			CFrame.new(x, 0.5, 10.5),
			COLORS.Metal,
			Enum.Material.Metal
		)
	end

	local display = Instance.new("Folder")
	display.Name = "Mutants"
	display.Parent = root
	self._display = display
	local battleFolder = Instance.new("Folder")
	battleFolder.Name = "Battle"
	battleFolder.Parent = root
	self._battleFolder = battleFolder

	local camera = workspace.CurrentCamera
	if camera then
		self._camera = camera
		self._previousCameraType = camera.CameraType
		self._previousCameraSubject = camera.CameraSubject
		self._previousCameraCFrame = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(-3, 16, -30), Vector3.new(-3, 3.2, 6))
	end

	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_animateBattle()
	end)
end

function WorldController:_clear(folder)
	if folder then
		folder:ClearAllChildren()
	end
end

function WorldController:SetState(snapshot)
	if not self._display or not self._battleFolder then
		return
	end
	self:_clear(self._display)
	for index, mutant in snapshot.Mutants or {} do
		if index <= 6 then
			makeBlob(self._display, mutant, CFrame.new(-13 + (index - 1) * 5.1, 0.5, 3))
		end
	end

	self._battle = snapshot.Battle
	self:_clear(self._battleFolder)
	if type(snapshot.Battle) == "table" then
		makeDummy(self._battleFolder)
		local fighter = nil
		for _, mutant in snapshot.Mutants or {} do
			if mutant.Id == snapshot.Battle.MutantId then
				fighter = mutant
				break
			end
		end
		if fighter then
			makeBlob(self._battleFolder, fighter, CFrame.new(-3, 0.5, 8))
		end
	end
end

function WorldController:_animateBattle()
	if type(self._battle) ~= "table" or not self._battleFolder then
		return
	end
	local dummy = self._battleFolder:FindFirstChild("CombatDummy")
	local fighter = self._battleFolder:FindFirstChild(tostring(self._battle.MutantId))
	local now = workspace:GetServerTimeNow()
	local duration = math.max(0.1, self._battle.EndsAt - self._battle.StartedAt)
	local progress = math.clamp((now - self._battle.StartedAt) / duration, 0, 1)
	local pulse = math.sin(now * 8)
	if dummy and dummy.PrimaryPart then
		dummy:PivotTo(
			CFrame.new(3, 2.2 + math.max(0, pulse) * 0.12, 8)
				* CFrame.Angles(0, 0, pulse * 0.06 * (1 - progress))
		)
	end
	if fighter and fighter.PrimaryPart then
		local lunge = math.max(0, math.sin(now * 5))
		fighter:PivotTo(CFrame.new(-3 + lunge * 2, 2 + lunge * 0.25, 8))
	end
end

function WorldController:Stop()
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end
	if self._camera and self._camera.Parent then
		self._camera.CameraType = self._previousCameraType or Enum.CameraType.Custom
		self._camera.CameraSubject = self._previousCameraSubject
		if self._previousCameraCFrame then
			self._camera.CFrame = self._previousCameraCFrame
		end
	end
	if self._root then
		self._root:Destroy()
		self._root = nil
	end
end

return WorldController
