--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatPresentation = require(
	ReplicatedStorage:WaitForChild("MutantLab")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("CombatPresentation")
)

local WorldController = {}
WorldController.__index = WorldController

local COLORS = {
	Ink = Color3.fromRGB(17, 24, 32),
	Metal = Color3.fromRGB(50, 62, 70),
	Cyan = Color3.fromRGB(71, 230, 210),
	Toxic = Color3.fromRGB(178, 255, 43),
	Purple = Color3.fromRGB(174, 91, 255),
	Orange = Color3.fromRGB(255, 164, 73),
	Red = Color3.fromRGB(241, 91, 102),
	Lime = Color3.fromRGB(166, 244, 83),
	DeepSlate = Color3.fromRGB(20, 26, 35),
	Panel = Color3.fromRGB(30, 38, 48),
	PanelSoft = Color3.fromRGB(27, 37, 47),
	Electric = Color3.fromRGB(255, 230, 70),
	Cryo = Color3.fromRGB(110, 220, 255),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function part(parent, name, size, cframe, color, material, canCollide)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = canCollide == true
	item.CanQuery = false
	item.CanTouch = false
	item.CastShadow = false
	item.Parent = parent
	return item
end

local function labelOn(parent, text, offset, textColor)
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
	textLabel.TextColor3 = textColor or Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = textLabel
end

local function spawnDamagePopup(parent, text, position, textColor, strokeColor)
	local popupPart = Instance.new("Part")
	popupPart.Name = "DamagePopup"
	popupPart.Transparency = 1
	popupPart.CanCollide = false
	popupPart.CanQuery = false
	popupPart.CanTouch = false
	popupPart.Anchored = true
	popupPart.CFrame = CFrame.new(position)
	popupPart.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 36)
	gui.AlwaysOnTop = true
	gui.Parent = popupPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 215, 60)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or Color3.fromRGB(180, 45, 25)
	stroke.Thickness = 2
	stroke.Parent = label

	local startClock = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not popupPart or not popupPart.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - startClock
		if elapsed >= 0.75 then
			conn:Disconnect()
			popupPart:Destroy()
			return
		end
		popupPart.CFrame = CFrame.new(position + Vector3.new(0, elapsed * 3.8, 0))
		local alpha = elapsed / 0.75
		label.TextTransparency = alpha
		stroke.Transparency = alpha
	end)
end

local function spawnLightRing(parent, position, color, maxRadius, duration)
	local ring = Instance.new("Part")
	ring.Name = "LightRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 0.5, 0.5)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color or COLORS.Cyan
	ring.Material = Enum.Material.SmoothPlastic
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.2
	ring.Parent = parent

	local startClock = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not ring or not ring.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - startClock
		if elapsed >= duration then
			conn:Disconnect()
			ring:Destroy()
			return
		end
		local alpha = elapsed / duration
		local radius = 0.5 + (maxRadius - 0.5) * alpha
		ring.Size = Vector3.new(0.08, radius, radius)
		ring.Transparency = 0.2 + 0.8 * alpha
	end)
end

local function spawnShockwave(parent, position, color, maxRadius, duration)
	local sphere = Instance.new("Part")
	sphere.Name = "Shockwave"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(0.5, 0.5, 0.5)
	sphere.CFrame = CFrame.new(position)
	sphere.Color = color or COLORS.Toxic
	sphere.Material = Enum.Material.ForceField
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.CastShadow = false
	sphere.Transparency = 0.3
	sphere.Parent = parent

	local startClock = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not sphere or not sphere.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - startClock
		if elapsed >= duration then
			conn:Disconnect()
			sphere:Destroy()
			return
		end
		local alpha = elapsed / duration
		local currentSize = 0.5 + (maxRadius - 0.5) * alpha
		sphere.Size = Vector3.new(currentSize, currentSize, currentSize)
		sphere.Transparency = 0.3 + 0.7 * alpha
	end)
end

local function spawnFloatingBanner(parent, text, position, textColor, strokeColor, duration)
	local bannerPart = Instance.new("Part")
	bannerPart.Name = "FloatingBanner"
	bannerPart.Transparency = 1
	bannerPart.CanCollide = false
	bannerPart.CanQuery = false
	bannerPart.CanTouch = false
	bannerPart.Anchored = true
	bannerPart.CFrame = CFrame.new(position)
	bannerPart.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 44)
	gui.AlwaysOnTop = true
	gui.Parent = bannerPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or Color3.fromRGB(20, 30, 40)
	stroke.Thickness = 2.5
	stroke.Parent = label

	local totalDuration = duration or 1.2
	local startClock = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not bannerPart or not bannerPart.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local elapsed = os.clock() - startClock
		if elapsed >= totalDuration then
			conn:Disconnect()
			bannerPart:Destroy()
			return
		end
		bannerPart.CFrame = CFrame.new(position + Vector3.new(0, elapsed * 2.2, 0))
		local alpha = elapsed / totalDuration
		if alpha > 0.6 then
			local fade = (alpha - 0.6) / 0.4
			label.TextTransparency = fade
			stroke.Transparency = fade
		end
	end)
end

local function makeBlob(parent, mutant, at, order)
	local model = Instance.new("Model")
	model.Name = tostring(mutant.Id)
	model:SetAttribute("MutantId", mutant.Id)
	model:SetAttribute("Order", order or 1)
	local isPlasma = mutant.Type == "PlasmaBlob"
	local toxic = mutant.Type == "ToxicBlob"
	local bodyColor = if isPlasma
		then Color3.fromRGB(150, 50, 255)
		elseif toxic then COLORS.Toxic
		else COLORS.Cyan
	local bodySize = if isPlasma
		then Vector3.new(3.8, 3.0, 3.8)
		elseif toxic then Vector3.new(3.5, 2.8, 3.5)
		else Vector3.new(3.1, 2.5, 3.1)
	local body =
		part(model, "Body", bodySize, at * CFrame.new(0, 1.5, 0), bodyColor, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	model:SetAttribute("BaseX", body.Position.X)
	model:SetAttribute("BaseY", body.Position.Y)
	model:SetAttribute("BaseZ", body.Position.Z)
	model:SetAttribute("BaseSizeX", bodySize.X)
	model:SetAttribute("BaseSizeY", bodySize.Y)
	model:SetAttribute("BaseSizeZ", bodySize.Z)

	for index, x in { -0.58, 0.58 } do
		local eyeColor = if isPlasma then Color3.fromRGB(120, 240, 255) else Color3.fromRGB(236, 255, 250)
		local eye = part(
			model,
			"Eye_" .. tostring(index),
			Vector3.new(0.5, 0.65, 0.28),
			at * CFrame.new(x, 1.85, -1.42),
			eyeColor,
			Enum.Material.SmoothPlastic
		)
		eye.Shape = Enum.PartType.Ball
		local pupil = part(
			model,
			"Pupil_" .. tostring(index),
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
				Enum.Material.SmoothPlastic
			)
			spike.Shape = Enum.PartType.Cylinder
		end
	elseif isPlasma then
		for index = 0, 3 do
			local angle = (math.pi * 2 / 4) * index + math.pi / 4
			local nodeCFrame = at
				* CFrame.new(math.cos(angle) * 1.6, 2.8, math.sin(angle) * 1.6)
				* CFrame.Angles(math.cos(angle) * 0.45, 0, -math.sin(angle) * 0.45)
			local node = part(
				model,
				"PlasmaNode",
				Vector3.new(0.45, 1.6, 0.45),
				nodeCFrame,
				Color3.fromRGB(110, 230, 255),
				Enum.Material.SmoothPlastic
			)
			node.Shape = Enum.PartType.Cylinder
		end
		local halo = part(
			model,
			"PlasmaHalo",
			Vector3.new(3.2, 0.12, 3.2),
			at * CFrame.new(0, 3.6, 0),
			Color3.fromRGB(120, 230, 255),
			Enum.Material.SmoothPlastic
		)
		halo.Shape = Enum.PartType.Cylinder
		halo.CFrame = at * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	end

	local displayName = if isPlasma then "PLASMA BLOB" elseif toxic then "TOXIC BLOB" else "BLOB"
	local labelColor = if isPlasma
		then Color3.fromRGB(140, 220, 255)
		elseif toxic then COLORS.Toxic
		else COLORS.Cyan
	labelOn(
		body,
		string.format("%s  •  Lv.%s", displayName, tostring(mutant.Level or 1)),
		Vector3.new(0, if isPlasma then 4.1 else 2.6, 0),
		labelColor
	)
	model.Parent = parent
	return model
end

local function makeHologramPlaceholder(parent, mutant, at, order)
	local model = Instance.new("Model")
	model.Name = tostring(mutant.Id)
	model:SetAttribute("MutantId", mutant.Id)
	model:SetAttribute("Order", order or 1)
	model:SetAttribute("IsHologram", true)

	local ghost = part(
		model,
		"Ghost",
		Vector3.new(2.8, 2.3, 2.8),
		at * CFrame.new(0, 1.4, 0),
		COLORS.Cyan,
		Enum.Material.ForceField
	)
	ghost.Shape = Enum.PartType.Ball
	ghost.Transparency = 0.55
	model.PrimaryPart = ghost

	local ring = part(
		model,
		"HoloRing",
		Vector3.new(3.8, 0.08, 3.8),
		at * CFrame.new(0, 0.25, 0),
		COLORS.Orange,
		Enum.Material.SmoothPlastic
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = at * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local displayName = if mutant.Type == "PlasmaBlob"
		then "PLASMA BLOB"
		elseif mutant.Type == "ToxicBlob" then "TOXIC BLOB"
		else "BLOB"
	labelOn(ghost, string.format("%s  •  IN TRAINING", displayName), Vector3.new(0, 2.4, 0), COLORS.Orange)
	model.Parent = parent
	return model
end

local function makeEnemyUnit(parent, enemy, at, order)
	local model = Instance.new("Model")
	model.Name = tostring(enemy.Id)
	model:SetAttribute("EnemyId", enemy.Id)
	model:SetAttribute("Order", order or 1)

	local elem = if enemy.Stats and enemy.Stats.EffectiveElements
		then enemy.Stats.EffectiveElements.Primary
		else "Toxin"
	local bodyColor = if elem == "Plasma"
		then Color3.fromRGB(170, 70, 255)
		elseif elem == "Toxin" then COLORS.Toxic
		elseif elem == "Cryo" then COLORS.Cryo
		elseif elem == "Electro" then COLORS.Electric
		elseif elem == "Shadow" then Color3.fromRGB(190, 40, 60)
		else COLORS.Orange

	local bodySize = Vector3.new(3.6, 3.2, 3.6)
	local body = part(model, "Body", bodySize, at * CFrame.new(0, 1.8, 0), bodyColor, Enum.Material.Neon)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	for index, x in { -0.6, 0.6 } do
		local eye = part(
			model,
			"Eye_" .. tostring(index),
			Vector3.new(0.5, 0.6, 0.3),
			at * CFrame.new(x, 2.1, -1.5),
			COLORS.Red,
			Enum.Material.Neon
		)
		eye.Shape = Enum.PartType.Ball
	end

	local hl = Instance.new("Highlight")
	hl.Name = "EnemyHighlight"
	hl.FillColor = bodyColor
	hl.FillTransparency = 0.65
	hl.OutlineColor = COLORS.Red
	hl.OutlineTransparency = 0.2
	hl.Adornee = model
	hl.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyUI"
	gui.Size = UDim2.fromOffset(160, 42)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = COLORS.Red
	nameLabel.Text = string.format("[E] %s", enemy.Name)
	nameLabel.Parent = gui

	local hpBarBg = Instance.new("Frame")
	hpBarBg.Size = UDim2.new(1, -20, 0, 6)
	hpBarBg.Position = UDim2.new(0, 10, 0, 22)
	hpBarBg.BackgroundColor3 = COLORS.PanelSoft
	hpBarBg.Parent = gui
	addCorner(hpBarBg, 3)

	local hpPct = math.clamp(enemy.CurrentHp / math.max(1, enemy.MaxHp), 0, 1)
	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.new(hpPct, 0, 1, 0)
	hpFill.BackgroundColor3 = if hpPct > 0.5
		then COLORS.Lime
		elseif hpPct > 0.25 then COLORS.Orange
		else COLORS.Red
	hpFill.Parent = hpBarBg
	addCorner(hpFill, 3)

	model.Parent = parent
	return model
end

local function makeDummy(parent, at)
	local baseCFrame = at or CFrame.new(0.5, 0.9, 8)
	local model = Instance.new("Model")
	model.Name = "CombatDummy"
	local root = part(
		model,
		"Root",
		Vector3.new(1.8, 3.6, 1.4),
		baseCFrame * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(224, 112, 70),
		Enum.Material.Wood
	)
	model.PrimaryPart = root
	local head = part(
		model,
		"Head",
		Vector3.new(1.8, 1.8, 1.8),
		baseCFrame * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(238, 153, 81),
		Enum.Material.Wood
	)
	head.Shape = Enum.PartType.Ball
	for _, x in { -1.3, 1.3 } do
		part(
			model,
			"Arm",
			Vector3.new(0.65, 3, 0.65),
			baseCFrame * CFrame.new(x, 2.1, 0),
			Color3.fromRGB(117, 75, 53),
			Enum.Material.Wood
		)
	end

	local hpGui = Instance.new("BillboardGui")
	hpGui.Name = "DummyHP"
	hpGui.Size = UDim2.fromOffset(160, 44)
	hpGui.StudsOffset = Vector3.new(0, 2.4, 0)
	hpGui.AlwaysOnTop = true
	hpGui.Parent = head

	local hpBg = Instance.new("Frame")
	hpBg.Name = "Background"
	hpBg.Size = UDim2.new(1, 0, 0, 10)
	hpBg.Position = UDim2.new(0, 0, 0, 24)
	hpBg.BackgroundColor3 = Color3.fromRGB(25, 32, 38)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = hpGui
	addCorner(hpBg, 5)

	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(60, 230, 110)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg
	addCorner(hpFill, 5)

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "Label"
	hpLabel.Size = UDim2.new(1, 0, 0, 18)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = string.format(
		"TARGET DUMMY • %d / %d HP",
		CombatPresentation.DummyMaxHp,
		CombatPresentation.DummyMaxHp
	)
	hpLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 12
	hpLabel.Parent = hpGui

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
	self._lastDamagePopupTime = 0
	self._lastHitIndex = 0
	self._displayedHp = CombatPresentation.DummyMaxHp
	self._battlingMutantType = "Blob"
	self._lightingEffects = {}
	self._knownMutants = nil
	self._activeMerge = nil
	self._mergeFolder = nil
	self._dnaHelixModel = nil
	self._portalRingModel = nil
	return self
end

function WorldController:Start()
	local root = Instance.new("Folder")
	root.Name = "MutantLabClient_" .. tostring(Players.LocalPlayer.UserId)
	root.Parent = workspace
	self._root = root

	local Lighting = game:GetService("Lighting")
	self._lightingEffects = {}
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(45, 52, 65)
		Lighting.OutdoorAmbient = Color3.fromRGB(35, 42, 55)
		Lighting.Brightness = 1.5

		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MutantLabColor"
		cc.Saturation = 0.12
		cc.Contrast = 0.1
		cc.Brightness = 0
		cc.TintColor = Color3.fromRGB(245, 248, 255)
		cc.Parent = Lighting
		table.insert(self._lightingEffects, cc)

		local bloom = Instance.new("BloomEffect")
		bloom.Name = "MutantLabBloom"
		bloom.Intensity = 0.35
		bloom.Size = 16
		bloom.Threshold = 1.15
		bloom.Parent = Lighting
		table.insert(self._lightingEffects, bloom)

		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "MutantLabAtmosphere"
		atmosphere.Density = 0.18
		atmosphere.Offset = 0
		atmosphere.Color = Color3.fromRGB(180, 210, 230)
		atmosphere.Decay = Color3.fromRGB(70, 95, 125)
		atmosphere.Glare = 0
		atmosphere.Haze = 0
		atmosphere.Parent = Lighting
		table.insert(self._lightingEffects, atmosphere)
	end)

	local function onCharacterAdded(char)
		task.spawn(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 5)
			if hrp and hrp:IsA("BasePart") then
				-- Safe character grounding: prevent void fall, zero momentum, orient towards lab
				if hrp.Position.Y < 0 or (hrp.Position - Vector3.new(0, 3, -12)).Magnitude > 90 then
					hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					hrp.CFrame = CFrame.lookAt(Vector3.new(0, 3.2, -12), Vector3.new(0, 3.2, 5))
				end
			end
			for _, desc in char:GetDescendants() do
				if desc:IsA("BasePart") or desc:IsA("Decal") then
					desc.LocalTransparencyModifier = 0
				end
			end
			char.DescendantAdded:Connect(function(desc)
				if desc:IsA("BasePart") or desc:IsA("Decal") then
					desc.LocalTransparencyModifier = 0
				end
			end)
		end)
	end
	if Players.LocalPlayer.Character then
		onCharacterAdded(Players.LocalPlayer.Character)
	end
	Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	local architecture = Instance.new("Folder")
	architecture.Name = "Architecture"
	architecture.Parent = root

	-- 1. Modular Sci-Fi Tiled Floor with Structural Sub-Floor
	part(
		architecture,
		"Floor",
		Vector3.new(62, 2, 50),
		CFrame.new(0, -1, 3),
		COLORS.DeepSlate,
		Enum.Material.Metal,
		true
	)

	-- Central Runway Corridor
	part(
		architecture,
		"CentralRunway",
		Vector3.new(5, 0.05, 22),
		CFrame.new(0, 0.03, -2),
		COLORS.Panel,
		Enum.Material.SmoothPlastic,
		false
	)
	part(
		architecture,
		"RunwayConduitL",
		Vector3.new(0.25, 0.08, 22),
		CFrame.new(-2.6, 0.04, -2),
		COLORS.Cyan,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"RunwayConduitR",
		Vector3.new(0.25, 0.08, 22),
		CFrame.new(2.6, 0.04, -2),
		COLORS.Cyan,
		Enum.Material.Neon,
		false
	)
	for _, z in { -8, -2, 4 } do
		part(
			architecture,
			"FloorTrench_" .. tostring(z),
			Vector3.new(36, 0.06, 0.25),
			CFrame.new(0, 0.03, z),
			COLORS.Cyan,
			Enum.Material.Neon,
			false
		)
	end

	-- 2. Arrival Deck Platform (Spawn Dais)
	part(
		architecture,
		"ArrivalDais",
		Vector3.new(12, 0.5, 12),
		CFrame.new(0, 0.25, -12),
		COLORS.Panel,
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"DaisRim",
		Vector3.new(12.4, 0.15, 12.4),
		CFrame.new(0, 0.52, -12),
		COLORS.Cyan,
		Enum.Material.Neon,
		false
	)
	local daisDisc = part(
		architecture,
		"DaisDisc",
		Vector3.new(0.08, 8, 8),
		CFrame.new(0, 0.53, -12) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Ink,
		Enum.Material.SmoothPlastic,
		false
	)
	daisDisc.Shape = Enum.PartType.Cylinder

	part(
		architecture,
		"Chevron1",
		Vector3.new(1.8, 0.08, 0.4),
		CFrame.new(-4.5, 0.54, -16.5) * CFrame.Angles(0, math.pi / 4, 0),
		COLORS.Orange,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"Chevron2",
		Vector3.new(1.8, 0.08, 0.4),
		CFrame.new(4.5, 0.54, -16.5) * CFrame.Angles(0, -math.pi / 4, 0),
		COLORS.Orange,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"Chevron3",
		Vector3.new(1.8, 0.08, 0.4),
		CFrame.new(-4.5, 0.54, -7.5) * CFrame.Angles(0, -math.pi / 4, 0),
		COLORS.Orange,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"Chevron4",
		Vector3.new(1.8, 0.08, 0.4),
		CFrame.new(4.5, 0.54, -7.5) * CFrame.Angles(0, math.pi / 4, 0),
		COLORS.Orange,
		Enum.Material.Neon,
		false
	)

	local arrivalCeiling = part(
		architecture,
		"ArrivalLightFixture",
		Vector3.new(3.5, 0.5, 3.5),
		CFrame.new(0, 15.5, -12),
		COLORS.Metal,
		Enum.Material.Metal
	)
	local arrivalSpot = Instance.new("SpotLight")
	arrivalSpot.Name = "ArrivalSpot"
	arrivalSpot.Color = Color3.fromRGB(210, 240, 255)
	arrivalSpot.Range = 24
	arrivalSpot.Angle = 55
	arrivalSpot.Brightness = 1.2
	arrivalSpot.Face = Enum.NormalId.Bottom
	arrivalSpot.Parent = arrivalCeiling
	labelOn(arrivalCeiling, "ARRIVAL DECK // SECTOR 0", Vector3.new(0, -1.2, 0), COLORS.Cyan)

	-- 3. Perimeter Walls & Panoramic Observation Viewport
	part(
		architecture,
		"BackWall",
		Vector3.new(62, 16, 2),
		CFrame.new(0, 8, 26),
		COLORS.Ink,
		Enum.Material.Metal,
		true
	)
	local obsWin = part(
		architecture,
		"ObservationWindow",
		Vector3.new(28, 8, 0.4),
		CFrame.new(0, 8, 25.9),
		Color3.fromRGB(70, 160, 220),
		Enum.Material.Glass,
		true
	)
	obsWin.Transparency = 0.45
	part(
		architecture,
		"WindowFrameTop",
		Vector3.new(29, 0.6, 0.8),
		CFrame.new(0, 12.2, 25.8),
		COLORS.Metal,
		Enum.Material.Metal
	)
	part(
		architecture,
		"WindowFrameBottom",
		Vector3.new(29, 0.6, 0.8),
		CFrame.new(0, 3.8, 25.8),
		COLORS.Metal,
		Enum.Material.Metal
	)
	labelOn(obsWin, "OBSERVATION DECK // CONTAINMENT SECTOR", Vector3.new(0, 4.8, -0.3), COLORS.Cyan)

	part(
		architecture,
		"FrontWall",
		Vector3.new(62, 16, 2),
		CFrame.new(0, 8, -20),
		COLORS.Ink,
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"AirlockArch",
		Vector3.new(16, 0.6, 2.4),
		CFrame.new(0, 12, -19.6),
		COLORS.Cyan,
		Enum.Material.Neon
	)

	part(
		architecture,
		"LeftWall",
		Vector3.new(2, 16, 48),
		CFrame.new(-31, 8, 3),
		COLORS.Panel,
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"RightWall",
		Vector3.new(2, 16, 48),
		CFrame.new(31, 8, 3),
		COLORS.Panel,
		Enum.Material.Metal,
		true
	)

	-- Wall Columns with Vertical Neon Conduits
	for _, z in { -12, -2, 8, 18 } do
		part(
			architecture,
			"ColL_" .. tostring(z),
			Vector3.new(1.2, 16, 2.2),
			CFrame.new(-30.2, 8, z),
			COLORS.DeepSlate,
			Enum.Material.Metal,
			true
		)
		part(
			architecture,
			"StripL_" .. tostring(z),
			Vector3.new(0.15, 14, 0.3),
			CFrame.new(-29.5, 8, z),
			COLORS.Cyan,
			Enum.Material.Neon
		)
		part(
			architecture,
			"ColR_" .. tostring(z),
			Vector3.new(1.2, 16, 2.2),
			CFrame.new(30.2, 8, z),
			COLORS.DeepSlate,
			Enum.Material.Metal,
			true
		)
		part(
			architecture,
			"StripR_" .. tostring(z),
			Vector3.new(0.15, 14, 0.3),
			CFrame.new(29.5, 8, z),
			COLORS.Cyan,
			Enum.Material.Neon
		)
	end

	-- 4. Ceiling & Structural Trusses
	part(
		architecture,
		"Ceiling",
		Vector3.new(62, 2, 48),
		CFrame.new(0, 16, 3),
		COLORS.DeepSlate,
		Enum.Material.Metal,
		true
	)
	for _, z in { -12, -2, 8, 18 } do
		part(
			architecture,
			"Truss_" .. tostring(z),
			Vector3.new(62, 1.2, 1.2),
			CFrame.new(0, 15, z),
			COLORS.Metal,
			Enum.Material.Metal
		)
		local trussLight = Instance.new("PointLight")
		trussLight.Name = "TrussLight"
		trussLight.Color = Color3.fromRGB(220, 240, 255)
		trussLight.Range = 22
		trussLight.Brightness = 0.45
		trussLight.Parent = architecture:FindFirstChild("Truss_" .. tostring(z))
	end

	-- 5. Station 1: Specimen Cryo-Tubes (Containment Pods)
	for _, spec in
		{
			{ x = -18, z = 14, color = COLORS.Cyan, label = "CRYO-CHAMBER 01" },
			{ x = 18, z = 14, color = COLORS.Toxic, label = "CRYO-CHAMBER 02" },
		}
	do
		local tubeBase = part(
			architecture,
			"TubeBase_" .. spec.x,
			Vector3.new(4.2, 0.8, 4.2),
			CFrame.new(spec.x, 0.4, spec.z),
			COLORS.Metal,
			Enum.Material.Metal,
			true
		)
		local tubeTop = part(
			architecture,
			"TubeTop_" .. spec.x,
			Vector3.new(4.2, 0.8, 4.2),
			CFrame.new(spec.x, 8.2, spec.z),
			COLORS.Metal,
			Enum.Material.Metal,
			true
		)
		local tubeGlass = part(
			architecture,
			"TubeGlass_" .. spec.x,
			Vector3.new(7.2, 3.8, 3.8),
			CFrame.new(spec.x, 4.3, spec.z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(100, 230, 245),
			Enum.Material.Glass
		)
		tubeGlass.Shape = Enum.PartType.Cylinder
		tubeGlass.Transparency = 0.5

		local tubeFluid = part(
			architecture,
			"TubeFluid_" .. spec.x,
			Vector3.new(6.6, 3.2, 3.2),
			CFrame.new(spec.x, 4.3, spec.z) * CFrame.Angles(0, 0, math.pi / 2),
			spec.color,
			Enum.Material.Neon
		)
		tubeFluid.Shape = Enum.PartType.Cylinder
		tubeFluid.Transparency = 0.65

		local podLight = Instance.new("PointLight")
		podLight.Name = "PodLight"
		podLight.Color = spec.color
		podLight.Range = 10
		podLight.Brightness = 0.85
		podLight.Parent = tubeFluid

		local bubbleEmitter = Instance.new("ParticleEmitter")
		bubbleEmitter.Name = "Bubbles"
		bubbleEmitter.Rate = 10
		bubbleEmitter.Speed = NumberRange.new(1.2, 2.5)
		bubbleEmitter.Acceleration = Vector3.new(0, 3, 0)
		bubbleEmitter.Lifetime = NumberRange.new(1.5, 2.5)
		bubbleEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 0.28),
		})
		bubbleEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.8),
		})
		bubbleEmitter.Color = ColorSequence.new(spec.color)
		bubbleEmitter.Parent = tubeFluid

		labelOn(tubeTop, spec.label, Vector3.new(0, 1.2, 0), spec.color)
	end

	-- 6. Station 2: Genetic Synthesis / Breeding Console (West Wing)
	part(
		architecture,
		"BreedingDais",
		Vector3.new(8, 0.5, 8),
		CFrame.new(-20, 0.25, -2),
		COLORS.Panel,
		Enum.Material.Metal,
		true
	)
	local breedingConsole = part(
		architecture,
		"BreedingConsole",
		Vector3.new(4, 2.4, 2),
		CFrame.new(-20, 1.4, -2),
		COLORS.Metal,
		Enum.Material.Metal,
		true
	)
	local synthScreenGui = Instance.new("SurfaceGui")
	synthScreenGui.Name = "SynthScreen"
	synthScreenGui.Face = Enum.NormalId.Front
	synthScreenGui.AlwaysOnTop = true
	synthScreenGui.Parent = breedingConsole

	local screenFrame = Instance.new("Frame")
	screenFrame.Size = UDim2.fromScale(1, 1)
	screenFrame.BackgroundColor3 = COLORS.Ink
	screenFrame.Parent = synthScreenGui

	local screenTitle = Instance.new("TextLabel")
	screenTitle.Size = UDim2.new(1, -12, 0, 32)
	screenTitle.Position = UDim2.new(0, 6, 0, 8)
	screenTitle.BackgroundTransparency = 1
	screenTitle.Text = "GENOME SYNTHESIS // LAB-01"
	screenTitle.TextColor3 = COLORS.Purple
	screenTitle.Font = Enum.Font.GothamBold
	screenTitle.TextScaled = true
	screenTitle.Parent = screenFrame

	local screenSub = Instance.new("TextLabel")
	screenSub.Size = UDim2.new(1, -12, 0, 24)
	screenSub.Position = UDim2.new(0, 6, 0, 44)
	screenSub.BackgroundTransparency = 1
	screenSub.Text = "RECOMBINATION SEQUENCE READY"
	screenSub.TextColor3 = COLORS.Cyan
	screenSub.Font = Enum.Font.Gotham
	screenSub.TextScaled = true
	screenSub.Parent = screenFrame

	local statusBar = Instance.new("Frame")
	statusBar.Size = UDim2.new(0.9, 0, 0, 12)
	statusBar.Position = UDim2.new(0.05, 0, 0, 80)
	statusBar.BackgroundColor3 = COLORS.Purple
	statusBar.BorderSizePixel = 0
	statusBar.Parent = screenFrame
	addCorner(statusBar, 4)

	local dnaHelixModel = Instance.new("Model")
	dnaHelixModel.Name = "DNAHelix"
	local helixCore = part(
		dnaHelixModel,
		"HelixCore",
		Vector3.new(0.6, 3.2, 0.6),
		CFrame.new(-20, 3.8, -2),
		COLORS.Cyan,
		Enum.Material.Neon
	)
	helixCore.Shape = Enum.PartType.Cylinder
	helixCore.Transparency = 0.5
	dnaHelixModel.PrimaryPart = helixCore

	local helixRing1 = part(
		dnaHelixModel,
		"HelixRing1",
		Vector3.new(0.12, 3.4, 3.4),
		CFrame.new(-20, 3.8, -2) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Purple,
		Enum.Material.Neon
	)
	helixRing1.Shape = Enum.PartType.Cylinder
	helixRing1.Transparency = 0.35

	local helixRing2 = part(
		dnaHelixModel,
		"HelixRing2",
		Vector3.new(0.12, 3.0, 3.0),
		CFrame.new(-20, 3.8, -2) * CFrame.Angles(math.pi / 4, 0, math.pi / 2),
		COLORS.Cyan,
		Enum.Material.Neon
	)
	helixRing2.Shape = Enum.PartType.Cylinder
	helixRing2.Transparency = 0.35

	dnaHelixModel.Parent = architecture
	self._dnaHelixModel = dnaHelixModel

	labelOn(breedingConsole, "GENETIC SYNTHESIS // BREEDING", Vector3.new(0, 2.4, 0), COLORS.Purple)

	-- 7. Station 3: Expedition Quantum Gateway (East Wing)
	local expPad = part(
		architecture,
		"ExpeditionPad",
		Vector3.new(0.4, 8, 8),
		CFrame.new(20, 0.2, -2) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Panel,
		Enum.Material.Metal,
		true
	)
	expPad.Shape = Enum.PartType.Cylinder

	local portalRing = part(
		architecture,
		"PortalRing",
		Vector3.new(0.12, 8.4, 8.4),
		CFrame.new(20, 0.4, -2) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Purple,
		Enum.Material.Neon,
		false
	)
	portalRing.Shape = Enum.PartType.Cylinder
	self._portalRingModel = portalRing

	local portalCol = part(
		architecture,
		"PortalColumn",
		Vector3.new(6, 5, 5),
		CFrame.new(20, 3.2, -2) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Purple,
		Enum.Material.ForceField,
		false
	)
	portalCol.Shape = Enum.PartType.Cylinder
	portalCol.Transparency = 0.65

	local portalLight = Instance.new("PointLight")
	portalLight.Name = "PortalLight"
	portalLight.Color = COLORS.Purple
	portalLight.Range = 12
	portalLight.Brightness = 1.0
	portalLight.Parent = portalCol

	labelOn(portalCol, "QUANTUM GATEWAY // EXPEDITIONS", Vector3.new(0, 3.8, 0), COLORS.Purple)

	-- 8. Station 4: Central Combat Arena & 6 Mutant Pads
	part(
		architecture,
		"ArenaPlatform",
		Vector3.new(15, 0.8, 6),
		CFrame.new(-3, 0.5, 8),
		COLORS.Metal,
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"ArenaRim",
		Vector3.new(15.4, 0.12, 6.4),
		CFrame.new(-3, 0.91, 8),
		COLORS.Orange,
		Enum.Material.Neon
	)
	part(
		architecture,
		"ArenaCenterLine",
		Vector3.new(0.25, 0.05, 5.8),
		CFrame.new(-3, 0.93, 8),
		Color3.fromRGB(255, 205, 110),
		Enum.Material.Neon
	)
	local chamberSign = part(
		architecture,
		"ChamberSign",
		Vector3.new(6.5, 1.2, 0.2),
		CFrame.new(-3, 7.8, 13.4),
		COLORS.Ink,
		Enum.Material.SmoothPlastic
	)
	labelOn(chamberSign, "TEST CHAMBER // SECTOR 1", Vector3.new(0, 0, 0.2), COLORS.Orange)

	local arenaSpotLight = Instance.new("SpotLight")
	arenaSpotLight.Name = "ArenaSpot"
	arenaSpotLight.Color = Color3.fromRGB(255, 230, 180)
	arenaSpotLight.Range = 24
	arenaSpotLight.Angle = 60
	arenaSpotLight.Brightness = 1.0
	arenaSpotLight.Face = Enum.NormalId.Bottom
	arenaSpotLight.Parent = chamberSign

	for index = 1, 6 do
		local x = -13 + (index - 1) * 5.1
		part(
			architecture,
			"Pad",
			Vector3.new(4.2, 0.35, 4.2),
			CFrame.new(x, 0.3, 3),
			COLORS.Panel,
			Enum.Material.Metal,
			true
		)
		local glowColor = if index % 2 == 0 then COLORS.Purple else COLORS.Cyan
		local padGlow = part(
			architecture,
			"PadGlow",
			Vector3.new(3.5, 0.12, 3.5),
			CFrame.new(x, 0.51, 3),
			glowColor,
			Enum.Material.Neon
		)
		local padLight = Instance.new("PointLight")
		padLight.Name = "PadLight"
		padLight.Color = glowColor
		padLight.Range = 5
		padLight.Brightness = 0.35
		padLight.Parent = padGlow
	end

	local display = Instance.new("Folder")
	display.Name = "Mutants"
	display.Parent = root
	self._display = display
	local battleFolder = Instance.new("Folder")
	battleFolder.Name = "Battle"
	battleFolder.Parent = root
	self._battleFolder = battleFolder
	local expeditionFolder = Instance.new("Folder")
	expeditionFolder.Name = "Expedition"
	expeditionFolder.Parent = root
	self._expeditionFolder = expeditionFolder

	local camera = workspace.CurrentCamera
	if camera then
		self._camera = camera
		camera.CameraType = Enum.CameraType.Custom
		local char = Players.LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				camera.CameraSubject = hum
			end
		end
	end

	self._renderConnection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		self:_animateBlobs()
		self:_animateBattle()
		if self._activeMerge then
			self:_updateMergeAnimation(now)
		end
		if self._dnaHelixModel and self._dnaHelixModel.PrimaryPart then
			self._dnaHelixModel:PivotTo(
				CFrame.new(-20, 3.8 + math.sin(now * 2) * 0.15, -2)
					* CFrame.Angles(0, now * 0.8, math.sin(now * 1.5) * 0.1)
			)
		end
		if self._portalRingModel then
			self._portalRingModel.CFrame = CFrame.new(20, 0.4 + math.sin(now * 3) * 0.04, -2)
				* CFrame.Angles(0, now * 1.4, 0)
				* CFrame.Angles(0, 0, math.pi / 2)
		end
	end)
end

function WorldController:_clear(folder)
	if folder then
		folder:ClearAllChildren()
	end
end

function WorldController:SetSelected(selectedIds)
	self._selectedIds = selectedIds or {}
	self:_updateSelectionHighlights()
end

function WorldController:_updateSelectionHighlights()
	if not self._display then
		return
	end
	for _, child in self._display:GetChildren() do
		local mutantId = child:GetAttribute("MutantId")
		local isSelected = mutantId and table.find(self._selectedIds or {}, mutantId) ~= nil
		local existing = child:FindFirstChild("SelectionHighlight")
		if isSelected then
			if not existing then
				local highlight = Instance.new("Highlight")
				highlight.Name = "SelectionHighlight"
				highlight.FillColor = COLORS.Cyan
				highlight.FillTransparency = 0.65
				highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				highlight.OutlineTransparency = 0.1
				highlight.Adornee = child
				highlight.Parent = child
			end
		else
			if existing then
				existing:Destroy()
			end
		end
	end
end

function WorldController:_startMergeAnimation(mutant1, mutant2, newMutant, targetIndex, padIndex1, padIndex2)
	if not self._root then
		return
	end
	self:_completeMergeAnimation()

	local folder = Instance.new("Folder")
	folder.Name = "MergeVFX"
	folder.Parent = self._root
	self._mergeFolder = folder

	local padCFrame1 = CFrame.new(-13 + (padIndex1 - 1) * 5.1, 0.5, 3)
	local padCFrame2 = CFrame.new(-13 + (padIndex2 - 1) * 5.1, 0.5, 3)
	local targetPadCFrame = CFrame.new(-13 + (targetIndex - 1) * 5.1, 0.5, 3)

	local pos1 = padCFrame1.Position
	local pos2 = padCFrame2.Position
	local midPos = (pos1 + pos2) * 0.5 + Vector3.new(0, 3.2, 0)

	local m1 = makeBlob(folder, mutant1, padCFrame1, 1)
	local m2 = makeBlob(folder, mutant2, padCFrame2, 2)

	local core = part(
		folder,
		"ReactionCore",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(midPos),
		COLORS.Cyan,
		Enum.Material.SmoothPlastic
	)
	core.Shape = Enum.PartType.Ball
	core.Transparency = 1

	local light = Instance.new("PointLight")
	light.Color = COLORS.Cyan
	light.Brightness = 0
	light.Range = 10
	light.Parent = core

	local newModel = makeBlob(folder, newMutant, CFrame.new(midPos), 1)
	for _, p in newModel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		elseif p:IsA("BillboardGui") then
			p.Enabled = false
		end
	end

	self._activeMerge = {
		startTime = os.clock(),
		pos1 = pos1,
		pos2 = pos2,
		midPos = midPos,
		targetPos = targetPadCFrame.Position,
		targetIndex = targetIndex,
		targetMutantId = newMutant.Id,
		targetType = newMutant.Type,
		m1 = m1,
		m2 = m2,
		core = core,
		light = light,
		newModel = newModel,
		vortexStarted = false,
		burstTriggered = false,
		landingTriggered = false,
	}
end

function WorldController:_updateMergeAnimation(now)
	local merge = self._activeMerge
	if not merge then
		return
	end
	local elapsed = now - merge.startTime
	local pos1 = merge.pos1
	local pos2 = merge.pos2
	local midPos = merge.midPos
	local targetPos = merge.targetPos
	local m1 = merge.m1
	local m2 = merge.m2
	local core = merge.core
	local light = merge.light
	local newModel = merge.newModel

	if elapsed < 0.45 then
		-- Phase 1: Leap to Center
		local t = elapsed / 0.45
		local arc = math.sin(t * math.pi) * 2.2
		local p1 = pos1:Lerp(midPos, t) + Vector3.new(0, arc, 0)
		local p2 = pos2:Lerp(midPos, t) + Vector3.new(0, arc, 0)
		if m1 and m1.PrimaryPart then
			m1:PivotTo(CFrame.new(p1))
		end
		if m2 and m2.PrimaryPart then
			m2:PivotTo(CFrame.new(p2))
		end
	elseif elapsed < 0.85 then
		-- Phase 2: Vortex / Synthesis Reaction
		if not merge.vortexStarted then
			merge.vortexStarted = true
			local bannerText = if merge.targetType == "PlasmaBlob"
				then "⚡ SYNTHESIZING PLASMA..."
				else "⚗ SYNTHESIZING MUTATION..."
			local bannerColor = if merge.targetType == "PlasmaBlob"
				then Color3.fromRGB(120, 230, 255)
				else COLORS.Purple
			spawnFloatingBanner(
				self._root,
				bannerText,
				midPos + Vector3.new(0, 2.2, 0),
				bannerColor,
				Color3.fromRGB(40, 10, 70),
				0.9
			)
			if core then
				core.Transparency = 0.2
			end
		end

		local t = (elapsed - 0.45) / 0.40
		local spinAngle = t * math.pi * 5
		local currentRadius = (1 - t) * 2.2
		local heightWobble = math.sin(t * 12) * 0.4

		local coreSize = 1.6 + math.sin(t * 16) * 0.8
		if core then
			core.Size = Vector3.new(coreSize, coreSize, coreSize)
			if merge.targetType == "PlasmaBlob" then
				core.Color = if t < 0.5 then COLORS.Toxic else Color3.fromRGB(120, 220, 255)
			else
				core.Color = if t < 0.5 then COLORS.Cyan else COLORS.Toxic
			end
		end
		if light then
			light.Brightness = 0.35 + math.sin(t * 16) * 0.25
			light.Color = core.Color
		end

		local p1 = midPos
			+ Vector3.new(
				math.cos(spinAngle) * currentRadius,
				heightWobble,
				math.sin(spinAngle) * currentRadius
			)
		local p2 = midPos
			+ Vector3.new(
				math.cos(spinAngle + math.pi) * currentRadius,
				-heightWobble,
				math.sin(spinAngle + math.pi) * currentRadius
			)
		local scale = math.clamp(1 - t, 0.05, 1)

		if m1 and m1.PrimaryPart then
			local b1 = m1:FindFirstChild("Body")
			if b1 then
				b1.Size = Vector3.new(3.1 * scale, 2.5 * scale, 3.1 * scale)
			end
			m1:PivotTo(CFrame.new(p1))
		end
		if m2 and m2.PrimaryPart then
			local b2 = m2:FindFirstChild("Body")
			if b2 then
				b2.Size = Vector3.new(3.1 * scale, 2.5 * scale, 3.1 * scale)
			end
			m2:PivotTo(CFrame.new(p2))
		end
	elseif elapsed < 1.35 then
		-- Phase 3: Chemical/Plasma Burst & Victorious Leap
		if not merge.burstTriggered then
			merge.burstTriggered = true
			if m1 and m1.Parent then
				m1:Destroy()
			end
			if m2 and m2.Parent then
				m2:Destroy()
			end
			if core then
				core.Transparency = 1
			end
			if light then
				light.Brightness = 0
			end
			local isPlasma = merge.targetType == "PlasmaBlob"
			local shockColor = if isPlasma then Color3.fromRGB(110, 230, 255) else COLORS.Toxic
			local ringColor = if isPlasma then Color3.fromRGB(180, 70, 255) else COLORS.Purple
			spawnShockwave(self._root, midPos, shockColor, 7.5, 0.45)
			spawnLightRing(self._root, midPos - Vector3.new(0, 1.5, 0), ringColor, 6.0, 0.45)

			for _, p in newModel:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 0
				elseif p:IsA("BillboardGui") then
					p.Enabled = true
				end
			end
		end

		local t = (elapsed - 0.85) / 0.50
		local arc = math.sin(t * math.pi) * 2.4
		local p = midPos:Lerp(targetPos + Vector3.new(0, 1.5, 0), t) + Vector3.new(0, arc, 0)
		if newModel and newModel.PrimaryPart then
			newModel:PivotTo(CFrame.new(p))
		end
	elseif elapsed < 1.45 then
		-- Phase 4: Landing on Pedestal
		if not merge.landingTriggered then
			merge.landingTriggered = true
			local isPlasma = merge.targetType == "PlasmaBlob"
			local bannerText = if isPlasma
				then "⚡ PLASMA BLOB SYNTHESIZED! ✨"
				else "☣ TOXIC BLOB SYNTHESIZED! ✨"
			local bannerColor = if isPlasma then Color3.fromRGB(120, 230, 255) else COLORS.Toxic
			local strokeColor = if isPlasma then Color3.fromRGB(40, 10, 70) else Color3.fromRGB(30, 80, 20)
			spawnLightRing(self._root, targetPos + Vector3.new(0, 0.2, 0), bannerColor, 4.5, 0.6)
			spawnFloatingBanner(
				self._root,
				bannerText,
				targetPos + Vector3.new(0, 4.2, 0),
				bannerColor,
				strokeColor,
				1.2
			)
			if newModel and newModel.PrimaryPart then
				newModel:PivotTo(CFrame.new(targetPos + Vector3.new(0, 1.5, 0)))
			end
		end
	else
		-- Finished
		self:_completeMergeAnimation()
	end
end

function WorldController:_completeMergeAnimation()
	if self._activeMerge then
		local targetMutantId = self._activeMerge.targetMutantId
		self._activeMerge = nil
		if self._mergeFolder then
			self._mergeFolder:Destroy()
			self._mergeFolder = nil
		end
		if self._display and targetMutantId then
			local model = self._display:FindFirstChild(tostring(targetMutantId))
			if model then
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = 0
					elseif p:IsA("BillboardGui") then
						p.Enabled = true
					end
				end
			end
		end
	end
end

function WorldController:HandleActionResult(action, ok, _code)
	if not self._root or not ok then
		return
	end
	if action == "BreedMutants" then
		spawnShockwave(self._root, Vector3.new(-20, 3.8, -2), COLORS.Purple, 6, 0.8)
		spawnFloatingBanner(
			self._root,
			"🧬 GENETIC SYNTHESIS COMPLETE!",
			Vector3.new(-20, 5.5, -2),
			COLORS.Lime,
			Color3.fromRGB(30, 15, 50),
			1.4
		)
	elseif action == "StartExpedition" then
		spawnShockwave(self._root, Vector3.new(20, 3.2, -2), COLORS.Purple, 8, 1.0)
		spawnFloatingBanner(
			self._root,
			"⚡ SQUAD DEPLOYED TO EXPEDITION!",
			Vector3.new(20, 5.5, -2),
			COLORS.Cyan,
			Color3.fromRGB(20, 40, 60),
			1.4
		)
	elseif action == "SelectCombatAction" then
		spawnShockwave(self._root, Vector3.new(20, 1.0, -4), COLORS.Cyan, 5, 0.6)
		spawnFloatingBanner(
			self._root,
			"⚔️ TURN EXECUTED!",
			Vector3.new(20, 3.5, -4),
			COLORS.Cyan,
			Color3.fromRGB(15, 35, 50),
			1.0
		)
	elseif action == "SecureLoot" then
		spawnShockwave(self._root, Vector3.new(20, 1.0, -2), COLORS.Lime, 7, 0.8)
		spawnFloatingBanner(
			self._root,
			"💎 LOOT SECURED!",
			Vector3.new(20, 4.0, -2),
			COLORS.Lime,
			Color3.fromRGB(20, 45, 20),
			1.2
		)
	elseif action == "ProceedNextRoom" then
		spawnShockwave(self._root, Vector3.new(20, 3.2, -2), COLORS.Purple, 8, 1.0)
		spawnFloatingBanner(
			self._root,
			"🚪 ADVANCING ROOM...",
			Vector3.new(20, 5.0, -2),
			COLORS.Purple,
			Color3.fromRGB(30, 15, 50),
			1.2
		)
	elseif action == "Evacuate" then
		spawnShockwave(self._root, Vector3.new(20, 3.2, -2), COLORS.Red, 8, 1.0)
		spawnFloatingBanner(
			self._root,
			"🏃 SQUAD EVACUATED!",
			Vector3.new(20, 5.0, -2),
			COLORS.Red,
			Color3.fromRGB(50, 15, 15),
			1.2
		)
	end
end

function WorldController:SetState(snapshot)
	if not self._display or not self._battleFolder then
		return
	end
	local battlingMutantId = if type(snapshot.Battle) == "table" then snapshot.Battle.MutantId else nil
	local previousBattleId = if type(self._battle) == "table" then self._battle.Id else nil
	local nextBattleId = if type(snapshot.Battle) == "table" then snapshot.Battle.Id else nil
	local isSameBattle = previousBattleId ~= nil and previousBattleId == nextBattleId

	-- Detect transitions if already initialized
	local isSpawnDetected = false
	local addedMutant = nil

	if self._knownMutants ~= nil then
		local oldIds = {}
		local oldIndexById = {}
		for idx, m in self._knownMutants do
			table.insert(oldIds, m.Id)
			oldIndexById[m.Id] = idx
		end

		local newIds = {}
		local added = {}
		for idx, m in snapshot.Mutants or {} do
			table.insert(newIds, m.Id)
			if not table.find(oldIds, m.Id) then
				table.insert(added, { mutant = m, index = idx })
			end
		end

		local removed = {}
		for idx, m in self._knownMutants do
			if not table.find(newIds, m.Id) then
				table.insert(removed, { mutant = m, index = idx })
			end
		end

		if
			#removed == 2
			and #added == 1
			and (added[1].mutant.Type == "ToxicBlob" or added[1].mutant.Type == "PlasmaBlob")
		then
			-- Merge detected!
			self:_startMergeAnimation(
				removed[1].mutant,
				removed[2].mutant,
				added[1].mutant,
				added[1].index,
				removed[1].index,
				removed[2].index
			)
		elseif #added == 1 and #removed == 0 then
			-- Spawn detected!
			isSpawnDetected = true
			addedMutant = added[1].mutant
		end
	end

	self._knownMutants = snapshot.Mutants or {}

	local expeditionMutantIds = {}
	local inExpedition = false
	if snapshot.Expedition then
		inExpedition = snapshot.Expedition.Status == "InCombat"
			or snapshot.Expedition.Status == "AtTerminal"
			or snapshot.Expedition.Status == "Exploring"

		if snapshot.Expedition.CurrentCombat and snapshot.Expedition.CurrentCombat.PlayerTeam.Active then
			for _, u in snapshot.Expedition.CurrentCombat.PlayerTeam.Active do
				if u.IsAlive ~= false and u.CurrentHp and u.CurrentHp > 0 then
					expeditionMutantIds[u.Id] = u
				end
			end
		end
	end

	self:_clear(self._display)
	for index, mutant in snapshot.Mutants or {} do
		if index <= 6 then
			local padCFrame = CFrame.new(-13 + (index - 1) * 5.1, 0.5, 3)
			local model
			if mutant.Id == battlingMutantId or expeditionMutantIds[mutant.Id] then
				model = makeHologramPlaceholder(self._display, mutant, padCFrame, index)
			else
				model = makeBlob(self._display, mutant, padCFrame, index)
			end

			-- If this mutant is actively being animated in MergeVFX, keep it hidden in self._display until merge finishes
			if self._activeMerge and mutant.Id == self._activeMerge.targetMutantId then
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						p.Transparency = 1
					elseif p:IsA("BillboardGui") then
						p.Enabled = false
					end
				end
			elseif isSpawnDetected and addedMutant and mutant.Id == addedMutant.Id then
				-- Play spawn incubator bounce!
				model:SetAttribute("SpawnStartTime", os.clock())
				spawnLightRing(self._root, padCFrame.Position + Vector3.new(0, 0.2, 0), COLORS.Cyan, 4.2, 0.6)
				spawnFloatingBanner(
					self._root,
					"✨ NEW BLOB CREATED!",
					padCFrame.Position + Vector3.new(0, 3.8, 0),
					COLORS.Cyan,
					Color3.fromRGB(15, 65, 80),
					1.0
				)
			end
		end
	end
	self:_updateSelectionHighlights()

	if self._camera then
		if inExpedition then
			self._camera.CameraType = Enum.CameraType.Scriptable
			self._camera.CFrame = CFrame.new(20, 4.5, 3.5) * CFrame.Angles(math.rad(-15), 0, 0)
		else
			self._camera.CameraType = Enum.CameraType.Custom
			local char = Players.LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					self._camera.CameraSubject = hum
				end
			end
		end
	end

	self._battle = snapshot.Battle
	if not isSameBattle then
		self._lastHitIndex = 0
		self._displayedHp = CombatPresentation.DummyMaxHp
		self._battlingMutantType = "Blob"
		self:_clear(self._battleFolder)
		if type(snapshot.Battle) == "table" then
			makeDummy(self._battleFolder, CFrame.new(0.5, 0.9, 8))
			local fighter = nil
			for _, mutant in snapshot.Mutants or {} do
				if mutant.Id == snapshot.Battle.MutantId then
					fighter = mutant
					self._battlingMutantType = mutant.Type
					break
				end
			end
			if fighter then
				makeBlob(self._battleFolder, fighter, CFrame.new(-6.5, 0.9, 8), 1)
			end
		end
	end

	-- Expedition 3D Combat Visualization
	if self._expeditionFolder then
		self:_clear(self._expeditionFolder)
		if snapshot.Expedition and snapshot.Expedition.InCombat and snapshot.Expedition.CurrentCombat then
			local combat = snapshot.Expedition.CurrentCombat

			-- Render Enemies
			local enemyTeam = combat.EnemyTeam
			if enemyTeam and enemyTeam.Active then
				local livingEnemies = {}
				for _, enemy in enemyTeam.Active do
					if (enemy.IsAlive ~= false) and enemy.CurrentHp and enemy.CurrentHp > 0 then
						table.insert(livingEnemies, enemy)
					end
				end
				local count = #livingEnemies
				for i, enemy in livingEnemies do
					local offsetX = (i - (count + 1) / 2) * 3.8
					local at = CFrame.new(20 + offsetX, 1.0, -6) * CFrame.Angles(0, math.pi, 0)
					makeEnemyUnit(self._expeditionFolder, enemy, at, i)
				end
			end

			-- Render Player Squad
			local playerTeam = combat.PlayerTeam
			if playerTeam and playerTeam.Active then
				local livingPlayers = {}
				for _, p in playerTeam.Active do
					if p.IsAlive ~= false and p.CurrentHp and p.CurrentHp > 0 then
						table.insert(livingPlayers, p)
					end
				end
				local pCount = #livingPlayers
				for i, p in livingPlayers do
					local offsetX = (i - (pCount + 1) / 2) * 3.8
					-- Place player blobs closer to camera (Z = -0.5), facing enemies (front is -Z so rotation is 0)
					local at = CFrame.new(20 + offsetX, 0.4, -0.5)
					makeBlob(self._expeditionFolder, p, at, i)
				end
			end
		end
	end
end

function WorldController:_animateBlobs()
	if not self._display then
		return
	end
	local now = workspace:GetServerTimeNow()
	for _, child in self._display:GetChildren() do
		local body = child:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			local order = child:GetAttribute("Order") or 1
			local baseX = child:GetAttribute("BaseX")
			local baseY = child:GetAttribute("BaseY")
			local baseZ = child:GetAttribute("BaseZ")
			local sizeX = child:GetAttribute("BaseSizeX")
			local sizeY = child:GetAttribute("BaseSizeY")
			local sizeZ = child:GetAttribute("BaseSizeZ")

			if baseX and baseY and sizeX then
				local spawnStart = child:GetAttribute("SpawnStartTime")
				if spawnStart then
					local spawnElapsed = os.clock() - spawnStart
					if spawnElapsed < 0.75 then
						local dropY = 0
						local scaleY = 1
						local scaleXZ = 1
						if spawnElapsed < 0.35 then
							local t = spawnElapsed / 0.35
							dropY = (1 - t) * (1 - t) * 4.5
							scaleY = 1.0 + (1 - t) * 0.25
							scaleXZ = 1.0 - (1 - t) * 0.15
						elseif spawnElapsed < 0.5 then
							local t = (spawnElapsed - 0.35) / 0.15
							local squashFactor = math.sin(t * math.pi)
							scaleY = 1.0 - squashFactor * 0.45
							scaleXZ = 1.0 + squashFactor * 0.35
						else
							local t = (spawnElapsed - 0.5) / 0.25
							local rebound = math.sin(t * math.pi) * 0.22
							scaleY = 1.0 + rebound
							scaleXZ = 1.0 - rebound * 0.15
						end
						body.Size = Vector3.new(sizeX * scaleXZ, sizeY * scaleY, sizeZ * scaleXZ)
						body.Position = Vector3.new(baseX, baseY + dropY, baseZ)
						continue
					else
						child:SetAttribute("SpawnStartTime", nil)
					end
				end

				local wave = math.sin(now * 3 + order * 0.9)
				local squashY = 1 + wave * 0.08
				local stretchXZ = 1 - wave * 0.04
				body.Size = Vector3.new(sizeX * stretchXZ, sizeY * squashY, sizeZ * stretchXZ)
				body.Position = Vector3.new(baseX, baseY + wave * 0.06, baseZ)
			end

			local blinkTimer = (now + order * 1.3) % 3.8
			local isBlink = blinkTimer < 0.14
			for _, eyeIndex in { 1, 2 } do
				local eye = child:FindFirstChild("Eye_" .. tostring(eyeIndex))
				local pupil = child:FindFirstChild("Pupil_" .. tostring(eyeIndex))
				if eye and eye:IsA("BasePart") then
					eye.Size = if isBlink then Vector3.new(0.5, 0.08, 0.28) else Vector3.new(0.5, 0.65, 0.28)
				end
				if pupil and pupil:IsA("BasePart") then
					pupil.Transparency = if isBlink then 1 else 0
				end
			end
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
	local elapsed = math.clamp(now - self._battle.StartedAt, 0, duration)
	local isPlasma = (self._battlingMutantType == "PlasmaBlob")
	local isToxic = (self._battlingMutantType == "ToxicBlob")

	local attacks = CombatPresentation.GetAttacks(self._battlingMutantType)
	local currentHit, targetHp = CombatPresentation.Resolve(self._battlingMutantType, elapsed)
	local isImpact = false

	for _, attack in attacks do
		local impactDuration = if isPlasma then 0.25 else 0.22
		if attack.Impact and elapsed >= attack.Time and elapsed <= attack.Time + impactDuration then
			isImpact = true
			break
		end
	end

	local previousHit = self._lastHitIndex or 0
	for hitIndex = previousHit + 1, currentHit do
		local popupText = CombatPresentation.PopupText(attacks[hitIndex])
		if isPlasma then
			if hitIndex == 1 then
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 6.0, 8),
					Color3.fromRGB(120, 240, 255),
					Color3.fromRGB(30, 80, 160)
				)
			elseif hitIndex == 2 then
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 6.2, 8),
					Color3.fromRGB(200, 100, 255),
					Color3.fromRGB(70, 10, 130)
				)
			else
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 6.6, 8),
					Color3.fromRGB(255, 230, 80),
					Color3.fromRGB(160, 40, 10)
				)
			end
		elseif isToxic then
			if hitIndex == 1 or hitIndex == 4 then
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 5.8, 8),
					Color3.fromRGB(178, 255, 43)
				)
			elseif hitIndex == 2 or hitIndex == 3 or hitIndex == 5 or hitIndex == 6 then
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 6.2, 8),
					Color3.fromRGB(210, 110, 255),
					Color3.fromRGB(80, 20, 110)
				)
			elseif hitIndex == 7 then
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 5.8, 8),
					Color3.fromRGB(255, 120, 40),
					Color3.fromRGB(140, 40, 10)
				)
			else
				spawnDamagePopup(
					self._battleFolder,
					popupText,
					Vector3.new(0.5, 6.4, 8),
					Color3.fromRGB(255, 60, 60),
					Color3.fromRGB(110, 15, 15)
				)
			end
		else
			spawnDamagePopup(
				self._battleFolder,
				popupText,
				Vector3.new(0.5, 5.8, 8),
				Color3.fromRGB(255, 215, 60)
			)
		end
	end
	self._lastHitIndex = currentHit

	-- Smooth HP transition
	self._displayedHp = self._displayedHp or CombatPresentation.DummyMaxHp
	self._displayedHp = CombatPresentation.StepDisplayedHp(self._displayedHp, targetHp)
	local currentHpInt = math.clamp(math.ceil(self._displayedHp), 0, CombatPresentation.DummyMaxHp)
	local hpFraction = currentHpInt / CombatPresentation.DummyMaxHp

	-- Animate Dummy
	if dummy and dummy.PrimaryPart then
		local isKnockedOut = (isToxic and elapsed >= 5.0) or (isPlasma and elapsed >= 4.2)
		local tiltAngle = 0
		local dummyY = 2.7
		local dummyX = 0.5

		if isKnockedOut then
			tiltAngle = -1.15
			dummyY = 1.6
			dummyX = 1.2
		elseif isImpact then
			tiltAngle = -0.22
			dummyX = 0.8
		else
			local idleWave = math.sin(now * 4)
			dummyY = 2.7 + math.max(0, idleWave) * 0.08
			tiltAngle = idleWave * 0.04
		end

		dummy:PivotTo(CFrame.new(dummyX, dummyY, 8) * CFrame.Angles(0, 0, tiltAngle))

		local hpGui = dummy:FindFirstChild("Head") and dummy.Head:FindFirstChild("DummyHP")
		if hpGui then
			local fill = hpGui:FindFirstChild("Background") and hpGui.Background:FindFirstChild("Fill")
			local label = hpGui:FindFirstChild("Label")
			if fill then
				fill.Size = UDim2.new(hpFraction, 0, 1, 0)
				fill.BackgroundColor3 = Color3.fromHSV(hpFraction * 0.33, 0.85, 0.95)
			end
			if label then
				if isKnockedOut then
					label.Text =
						string.format("TARGET DUMMY • 0 / %d HP [KO]", CombatPresentation.DummyMaxHp)
					label.TextColor3 = Color3.fromRGB(255, 75, 75)
				elseif isPlasma and elapsed >= 1.2 then
					label.Text = string.format(
						"TARGET DUMMY • %d / %d HP [⚡ ELECTRIFIED]",
						currentHpInt,
						CombatPresentation.DummyMaxHp
					)
					label.TextColor3 = Color3.fromRGB(120, 230, 255)
				elseif isToxic and elapsed >= 0.9 then
					label.Text = string.format(
						"TARGET DUMMY • %d / %d HP [☣ POISONED]",
						currentHpInt,
						CombatPresentation.DummyMaxHp
					)
					label.TextColor3 = Color3.fromRGB(220, 130, 255)
				else
					label.Text = string.format(
						"TARGET DUMMY • %d / %d HP",
						currentHpInt,
						CombatPresentation.DummyMaxHp
					)
					label.TextColor3 = Color3.fromRGB(240, 245, 250)
				end
			end
		end

		-- Hit flash / Poison / Electrified Highlight
		local flash = dummy:FindFirstChild("CombatFlash")
		local isPoisonTick = isToxic
			and (currentHit == 2 or currentHit == 3 or currentHit == 5 or currentHit == 6 or currentHit == 8)
			and (elapsed % 0.6 < 0.2)

		if isImpact then
			if not flash then
				local h = Instance.new("Highlight")
				h.Name = "CombatFlash"
				h.FillColor = if isPlasma
					then Color3.fromRGB(120, 240, 255)
					elseif isToxic then Color3.fromRGB(178, 255, 43)
					else Color3.fromRGB(255, 70, 70)
				h.FillTransparency = 0.2
				h.OutlineTransparency = 0.3
				h.Adornee = dummy
				h.Parent = dummy
			end
		elseif isPlasma and elapsed >= 1.2 and not isKnockedOut and math.sin(now * 16) > 0.3 then
			if not flash then
				local h = Instance.new("Highlight")
				h.Name = "CombatFlash"
				h.FillColor = Color3.fromRGB(150, 70, 255)
				h.FillTransparency = 0.4
				h.OutlineTransparency = 0.5
				h.Adornee = dummy
				h.Parent = dummy
			end
		elseif
			isPoisonTick or (isToxic and elapsed >= 0.9 and not isKnockedOut and math.sin(now * 8) > 0.4)
		then
			if not flash then
				local h = Instance.new("Highlight")
				h.Name = "CombatFlash"
				h.FillColor = Color3.fromRGB(190, 60, 255)
				h.FillTransparency = 0.45
				h.OutlineTransparency = 0.6
				h.Adornee = dummy
				h.Parent = dummy
			end
		elseif flash then
			flash:Destroy()
		end
	end

	-- Animate Fighter
	if fighter and fighter.PrimaryPart then
		local fX = -6.5
		local fY = 2.3

		if isPlasma then
			if elapsed >= 4.4 then
				local hover = math.sin((elapsed - 4.4) * 6) * 0.35
				fY = 2.7 + hover
				fX = -6.5
			elseif elapsed >= 3.6 then
				local t = (elapsed - 3.6) / 0.6
				if t < 0.3 then
					fX = -6.5 - t * 2.0
					fY = 2.3
				elseif t < 0.7 then
					local st = (t - 0.3) / 0.4
					fX = -7.1 + st * 5.2
					fY = 2.3 + math.sin(st * math.pi) * 1.8
				else
					fX = -1.9
					fY = 2.3
				end
			elseif elapsed >= 2.0 then
				local t = (elapsed - 2.0) / 0.6
				if t < 0.5 then
					fX = -6.5 + (t / 0.5) * 4.6
					fY = 2.3 + math.sin((t / 0.5) * math.pi) * 1.2
				else
					local rt = (t - 0.5) / 0.5
					fX = -1.9 - rt * 4.6
					fY = 2.3
				end
			else
				local t = elapsed / 1.2
				if t >= 0.6 and t <= 1.0 then
					local st = (t - 0.6) / 0.4
					fX = -6.5 + st * 4.6
					fY = 2.3 + math.sin(st * math.pi) * 1.0
				else
					fX = -6.5
					fY = 2.3
				end
			end
		elseif isToxic then
			if elapsed >= 4.8 then
				local victoryWave = math.sin((elapsed - 4.8) * 8)
				fY = 2.3 + math.max(0, victoryWave) * 0.45
				fX = -6.5
			elseif elapsed >= 3.6 then
				local t = math.clamp((elapsed - 3.6) / 0.9, 0, 1)
				if t < 0.5 then
					fX = -6.5 - math.sin(t / 0.5 * math.pi) * 0.6
					fY = 2.3
				elseif t < 0.9 then
					local st = (t - 0.5) / 0.4
					fX = -6.5 + st * 4.6
					fY = 2.3 + math.sin(st * math.pi) * 1.5
				else
					fX = -1.9
					fY = 2.3
				end
			elseif elapsed >= 1.8 then
				local t = elapsed - 1.8
				if t < 0.4 then
					fX = -6.5 - math.sin(t / 0.4 * math.pi) * 0.4
					fY = 2.3
				elseif t < 0.9 then
					local st = (t - 0.4) / 0.5
					fX = -6.5 + st * 4.5
					fY = 2.3 + math.sin(st * math.pi) * 0.6
				elseif t < 1.2 then
					fX = -2.0
					fY = 2.3
				else
					local rt = (t - 1.2) / 0.3
					fX = -2.0 - rt * 4.5
					fY = 2.3 + math.sin(rt * math.pi) * 0.3
				end
			else
				local t = elapsed
				if t < 0.4 then
					fX = -6.5 - math.sin(t / 0.4 * math.pi) * 0.4
					fY = 2.3
				elseif t < 0.9 then
					local st = (t - 0.4) / 0.5
					fX = -6.5 + st * 4.5
					fY = 2.3 + math.sin(st * math.pi) * 0.6
				elseif t < 1.2 then
					fX = -2.0
					fY = 2.3
				else
					local rt = (t - 1.2) / 0.3
					fX = -2.0 - rt * 4.5
					fY = 2.3 + math.sin(rt * math.pi) * 0.3
				end
			end
		else
			if elapsed >= 4.8 then
				local victoryWave = math.sin((elapsed - 4.8) * 8)
				fY = 2.3 + math.max(0, victoryWave) * 0.35
				fX = -6.5
			else
				local cycleTime = elapsed % 1.2
				if cycleTime < 0.4 then
					local w = math.sin((cycleTime / 0.4) * math.pi)
					fX = -6.5 - w * 0.35
					fY = 2.3
				elseif cycleTime < 0.75 then
					local lt = (cycleTime - 0.4) / 0.35
					local jump = math.sin(lt * math.pi) * 0.5
					fX = -6.5 + lt * 4.5
					fY = 2.3 + jump
				elseif cycleTime < 0.95 then
					fX = -2.0
					fY = 2.3
				else
					local rt = (cycleTime - 0.95) / 0.25
					fX = -2.0 - rt * 4.5
					fY = 2.3 + math.sin(rt * math.pi) * 0.25
				end
			end
		end

		fighter:PivotTo(CFrame.new(fX, fY, 8))
	end
end

function WorldController:Stop()
	self:_completeMergeAnimation()
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end
	if self._lightingEffects then
		for _, effect in self._lightingEffects do
			if effect and effect.Parent then
				effect:Destroy()
			end
		end
		self._lightingEffects = nil
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
