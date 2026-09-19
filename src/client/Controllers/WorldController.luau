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
	Orange = Color3.fromRGB(255, 164, 73),
	Red = Color3.fromRGB(241, 91, 102),
	Lime = Color3.fromRGB(166, 244, 83),
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
	local toxic = mutant.Type == "ToxicBlob"
	local bodyColor = if toxic then COLORS.Toxic else COLORS.Cyan
	local bodySize = if toxic then Vector3.new(3.5, 2.8, 3.5) else Vector3.new(3.1, 2.5, 3.1)
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
		local eye = part(
			model,
			"Eye_" .. tostring(index),
			Vector3.new(0.5, 0.65, 0.28),
			at * CFrame.new(x, 1.85, -1.42),
			Color3.fromRGB(236, 255, 250),
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

	local displayName = if mutant.Type == "ToxicBlob" then "TOXIC BLOB" else "BLOB"
	labelOn(ghost, string.format("%s  •  IN TRAINING", displayName), Vector3.new(0, 2.4, 0), COLORS.Orange)
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
	hpLabel.Text = "TARGET DUMMY • 300 / 300 HP"
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
	self._displayedHp = 300
	self._battlingMutantType = "Blob"
	self._lightingEffects = {}
	self._knownMutants = nil
	self._activeMerge = nil
	self._mergeFolder = nil
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
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MutantLabColor"
		cc.Saturation = 0.05
		cc.Contrast = 0.04
		cc.Brightness = 0
		cc.Parent = Lighting
		table.insert(self._lightingEffects, cc)
	end)

	local function onCharacterAdded(char)
		task.spawn(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 5)
			if hrp and hrp:IsA("BasePart") then
				if hrp.Position.Y < 0 or (hrp.Position - Vector3.new(-3, 3, -10)).Magnitude > 60 then
					hrp.CFrame = CFrame.new(-3, 3, -10)
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

	-- Solid Laboratory Floor with collision
	part(
		architecture,
		"Floor",
		Vector3.new(48, 2, 44),
		CFrame.new(-3, -1, 0),
		Color3.fromRGB(28, 36, 44),
		Enum.Material.SmoothPlastic,
		true
	)

	-- Perimeter Walls with collision
	part(
		architecture,
		"BackWall",
		Vector3.new(48, 14, 2),
		CFrame.new(-3, 6, 15),
		COLORS.Ink,
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"FrontWall",
		Vector3.new(48, 8, 2),
		CFrame.new(-3, 3, -22),
		Color3.fromRGB(34, 44, 52),
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"LeftWall",
		Vector3.new(2, 14, 44),
		CFrame.new(-27, 6, 0),
		Color3.fromRGB(34, 44, 52),
		Enum.Material.Metal,
		true
	)
	part(
		architecture,
		"RightWall",
		Vector3.new(2, 14, 44),
		CFrame.new(21, 6, 0),
		Color3.fromRGB(34, 44, 52),
		Enum.Material.Metal,
		true
	)

	part(
		architecture,
		"LightStrip",
		Vector3.new(25, 0.35, 0.25),
		CFrame.new(0, 9, 13.42),
		COLORS.Cyan,
		Enum.Material.SmoothPlastic
	)
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
		Enum.Material.SmoothPlastic
	)
	part(
		architecture,
		"ArenaCenterLine",
		Vector3.new(0.25, 0.05, 5.8),
		CFrame.new(-3, 0.93, 8),
		Color3.fromRGB(255, 205, 110),
		Enum.Material.SmoothPlastic
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
	for index = 1, 6 do
		local x = -13 + (index - 1) * 5.1
		part(
			architecture,
			"Pad",
			Vector3.new(4.2, 0.35, 4.2),
			CFrame.new(x, 0.3, 3),
			Color3.fromRGB(34, 46, 54),
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
			Enum.Material.SmoothPlastic
		)
		local padLight = Instance.new("PointLight")
		padLight.Name = "PadLight"
		padLight.Color = glowColor
		padLight.Range = 4
		padLight.Brightness = 0.25
		padLight.Parent = padGlow
	end

	local chamberCeiling = part(
		architecture,
		"ChamberCeilingLight",
		Vector3.new(3, 0.4, 3),
		CFrame.new(0, 11, 8),
		COLORS.Metal,
		Enum.Material.Metal
	)
	local chamberSpot = Instance.new("SpotLight")
	chamberSpot.Name = "ChamberSpot"
	chamberSpot.Color = Color3.fromRGB(255, 230, 180)
	chamberSpot.Range = 22
	chamberSpot.Angle = 60
	chamberSpot.Brightness = 1.0
	chamberSpot.Face = Enum.NormalId.Bottom
	chamberSpot.Parent = chamberCeiling

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
		self:_animateBlobs()
		self:_animateBattle()
		if self._activeMerge then
			self:_updateMergeAnimation(os.clock())
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
			spawnFloatingBanner(
				self._root,
				"⚗ SYNTHESIZING MUTATION...",
				midPos + Vector3.new(0, 2.2, 0),
				COLORS.Purple,
				Color3.fromRGB(60, 20, 80),
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
			core.Color = if t < 0.5 then COLORS.Cyan else COLORS.Toxic
		end
		if light then
			light.Brightness = 0.35 + math.sin(t * 16) * 0.25
			light.Color = if t < 0.5 then COLORS.Cyan else COLORS.Toxic
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
		-- Phase 3: Chemical Burst & Victorious Leap
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
			spawnShockwave(self._root, midPos, COLORS.Toxic, 7.5, 0.45)
			spawnLightRing(self._root, midPos - Vector3.new(0, 1.5, 0), COLORS.Purple, 6.0, 0.45)

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
			spawnLightRing(self._root, targetPos + Vector3.new(0, 0.2, 0), COLORS.Toxic, 4.5, 0.6)
			spawnFloatingBanner(
				self._root,
				"☣ TOXIC BLOB SYNTHESIZED! ✨",
				targetPos + Vector3.new(0, 4.2, 0),
				COLORS.Toxic,
				Color3.fromRGB(30, 80, 20),
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

function WorldController:HandleActionResult(_action, _ok, _code)
	-- Ready for action-specific reactions if needed
end

function WorldController:SetState(snapshot)
	if not self._display or not self._battleFolder then
		return
	end
	local battlingMutantId = if type(snapshot.Battle) == "table" then snapshot.Battle.MutantId else nil

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

		if #removed == 2 and #added == 1 and added[1].mutant.Type == "ToxicBlob" then
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

	self:_clear(self._display)
	for index, mutant in snapshot.Mutants or {} do
		if index <= 6 then
			local padCFrame = CFrame.new(-13 + (index - 1) * 5.1, 0.5, 3)
			local model
			if mutant.Id == battlingMutantId then
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

	self._battle = snapshot.Battle
	self._lastHitIndex = 0
	self._displayedHp = 300
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
	local isToxic = (self._battlingMutantType == "ToxicBlob")

	local currentHit = 0
	local targetHp = 300
	local isImpact = false

	if isToxic then
		-- Toxic Blob: Heavy strikes + 5 ticking poison procs!
		if elapsed >= 5.0 then
			currentHit = 8
			targetHp = 0
		elseif elapsed >= 4.5 then
			currentHit = 7
			targetHp = 60
		elseif elapsed >= 3.9 then
			currentHit = 6
			targetHp = 130
		elseif elapsed >= 3.3 then
			currentHit = 5
			targetHp = 150
		elseif elapsed >= 2.7 then
			currentHit = 4
			targetHp = 170
		elseif elapsed >= 2.1 then
			currentHit = 3
			targetHp = 225
		elseif elapsed >= 1.5 then
			currentHit = 2
			targetHp = 240
		elseif elapsed >= 0.9 then
			currentHit = 1
			targetHp = 255
		end

		for _, hitTime in { 0.9, 2.7, 4.5 } do
			if elapsed >= hitTime and elapsed <= hitTime + 0.22 then
				isImpact = true
				break
			end
		end

		if currentHit > (self._lastHitIndex or 0) then
			self._lastHitIndex = currentHit
			if currentHit == 1 then
				spawnDamagePopup(
					self._battleFolder,
					"-45",
					Vector3.new(0.5, 5.8, 8),
					Color3.fromRGB(178, 255, 43)
				)
			elseif currentHit == 2 or currentHit == 3 then
				spawnDamagePopup(
					self._battleFolder,
					"☣ -15 POISON",
					Vector3.new(0.5, 6.2, 8),
					Color3.fromRGB(210, 110, 255),
					Color3.fromRGB(80, 20, 110)
				)
			elseif currentHit == 4 then
				spawnDamagePopup(
					self._battleFolder,
					"-55",
					Vector3.new(0.5, 5.8, 8),
					Color3.fromRGB(178, 255, 43)
				)
			elseif currentHit == 5 or currentHit == 6 then
				spawnDamagePopup(
					self._battleFolder,
					"☣ -20 POISON",
					Vector3.new(0.5, 6.2, 8),
					Color3.fromRGB(210, 110, 255),
					Color3.fromRGB(80, 20, 110)
				)
			elseif currentHit == 7 then
				spawnDamagePopup(
					self._battleFolder,
					"☣ TOXIC SLAM! -70",
					Vector3.new(0.5, 5.8, 8),
					Color3.fromRGB(255, 120, 40),
					Color3.fromRGB(140, 40, 10)
				)
			elseif currentHit == 8 then
				spawnDamagePopup(
					self._battleFolder,
					"☣ FATAL POISON! -60",
					Vector3.new(0.5, 6.4, 8),
					Color3.fromRGB(255, 60, 60),
					Color3.fromRGB(110, 15, 15)
				)
			end
		end
	else
		-- Normal Blob: 4 physical body slams, leaves dummy with 120/300 HP standing!
		if elapsed >= 4.6 then
			currentHit = 4
			targetHp = 120
		elseif elapsed >= 3.4 then
			currentHit = 3
			targetHp = 165
		elseif elapsed >= 2.2 then
			currentHit = 2
			targetHp = 210
		elseif elapsed >= 1.0 then
			currentHit = 1
			targetHp = 255
		end

		for _, hitTime in { 1.0, 2.2, 3.4, 4.6 } do
			if elapsed >= hitTime and elapsed <= hitTime + 0.22 then
				isImpact = true
				break
			end
		end

		if currentHit > (self._lastHitIndex or 0) then
			self._lastHitIndex = currentHit
			local dmg = if currentHit == 4 then "-25" else "-20"
			spawnDamagePopup(self._battleFolder, dmg, Vector3.new(0.5, 5.8, 8), Color3.fromRGB(255, 215, 60))
		end
	end

	-- Smooth HP transition
	self._displayedHp = self._displayedHp or 300
	self._displayedHp = self._displayedHp + (targetHp - self._displayedHp) * 0.14
	local currentHpInt = math.clamp(math.ceil(self._displayedHp), 0, 300)
	local hpFraction = currentHpInt / 300

	-- Animate Dummy
	if dummy and dummy.PrimaryPart then
		local isKnockedOut = isToxic and elapsed >= 5.0
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
					label.Text = "TARGET DUMMY • 0 / 300 HP [KO]"
					label.TextColor3 = Color3.fromRGB(255, 75, 75)
				elseif isToxic and elapsed >= 0.9 then
					label.Text = string.format("TARGET DUMMY • %d / 300 HP [☣ POISONED]", currentHpInt)
					label.TextColor3 = Color3.fromRGB(220, 130, 255)
				else
					label.Text = string.format("TARGET DUMMY • %d / 300 HP", currentHpInt)
					label.TextColor3 = Color3.fromRGB(240, 245, 250)
				end
			end
		end

		-- Hit flash / Poison Highlight
		local flash = dummy:FindFirstChild("CombatFlash")
		local isPoisonTick = isToxic
			and (currentHit == 2 or currentHit == 3 or currentHit == 5 or currentHit == 6 or currentHit == 8)
			and (elapsed % 0.6 < 0.2)

		if isImpact then
			if not flash then
				local h = Instance.new("Highlight")
				h.Name = "CombatFlash"
				h.FillColor = if isToxic then Color3.fromRGB(178, 255, 43) else Color3.fromRGB(255, 70, 70)
				h.FillTransparency = 0.25
				h.OutlineTransparency = 0.4
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

		if isToxic then
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
