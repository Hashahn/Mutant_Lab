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

local function spawnDamagePopup(parent, text, position)
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
	gui.Size = UDim2.fromOffset(120, 36)
	gui.AlwaysOnTop = true
	gui.Parent = popupPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 45, 25)
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

local function makeBlob(parent, mutant, at, order)
	local model = Instance.new("Model")
	model.Name = tostring(mutant.Id)
	model:SetAttribute("MutantId", mutant.Id)
	model:SetAttribute("Order", order or 1)
	local toxic = mutant.Type == "ToxicBlob"
	local bodyColor = if toxic then COLORS.Toxic else COLORS.Cyan
	local bodySize = if toxic then Vector3.new(3.5, 2.8, 3.5) else Vector3.new(3.1, 2.5, 3.1)
	local body = part(model, "Body", bodySize, at * CFrame.new(0, 1.5, 0), bodyColor, Enum.Material.Neon)
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
			Enum.Material.Neon
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
		Enum.Material.Neon
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
	hpLabel.Text = "TARGET DUMMY • 100%"
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
	self._lightingEffects = {}
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
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "MutantLabBloom"
		bloom.Intensity = 0.85
		bloom.Size = 24
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
		table.insert(self._lightingEffects, bloom)

		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MutantLabColor"
		cc.Saturation = 0.18
		cc.Contrast = 0.12
		cc.Brightness = 0.02
		cc.Parent = Lighting
		table.insert(self._lightingEffects, cc)
	end)

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
		"ArenaPlatform",
		Vector3.new(15, 0.8, 6),
		CFrame.new(-3, 0.5, 8),
		COLORS.Metal,
		Enum.Material.Metal
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
		padLight.Range = 10
		padLight.Brightness = 1.8
		padLight.Parent = padGlow
	end

	local chamberCeiling = part(
		architecture,
		"ChamberCeilingLight",
		Vector3.new(3, 0.4, 3),
		CFrame.new(0, 11, 8),
		Color3.fromRGB(255, 240, 200),
		Enum.Material.Neon
	)
	local chamberSpot = Instance.new("SpotLight")
	chamberSpot.Name = "ChamberSpot"
	chamberSpot.Color = Color3.fromRGB(255, 230, 180)
	chamberSpot.Range = 25
	chamberSpot.Angle = 65
	chamberSpot.Brightness = 2.2
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
		self._previousCameraType = camera.CameraType
		self._previousCameraSubject = camera.CameraSubject
		self._previousCameraCFrame = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(-3, 16, -30), Vector3.new(-3, 3.2, 6))
	end

	self._renderConnection = RunService.RenderStepped:Connect(function()
		self:_animateBlobs()
		self:_animateBattle()
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

function WorldController:SetState(snapshot)
	if not self._display or not self._battleFolder then
		return
	end
	local battlingMutantId = if type(snapshot.Battle) == "table" then snapshot.Battle.MutantId else nil

	self:_clear(self._display)
	for index, mutant in snapshot.Mutants or {} do
		if index <= 6 then
			local padCFrame = CFrame.new(-13 + (index - 1) * 5.1, 0.5, 3)
			if mutant.Id == battlingMutantId then
				makeHologramPlaceholder(self._display, mutant, padCFrame, index)
			else
				makeBlob(self._display, mutant, padCFrame, index)
			end
		end
	end
	self:_updateSelectionHighlights()

	self._battle = snapshot.Battle
	self:_clear(self._battleFolder)
	if type(snapshot.Battle) == "table" then
		makeDummy(self._battleFolder, CFrame.new(0.5, 0.9, 8))
		local fighter = nil
		for _, mutant in snapshot.Mutants or {} do
			if mutant.Id == snapshot.Battle.MutantId then
				fighter = mutant
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
	local progress = math.clamp((now - self._battle.StartedAt) / duration, 0, 1)
	local pulse = math.sin(now * 8)
	local lunge = math.max(0, math.sin(now * 5))

	if dummy and dummy.PrimaryPart then
		dummy:PivotTo(
			CFrame.new(0.5, 2.7 + math.max(0, pulse) * 0.14, 8)
				* CFrame.Angles(0, 0, pulse * 0.08 * (1 - progress))
		)

		local hpGui = dummy:FindFirstChild("Head") and dummy.Head:FindFirstChild("DummyHP")
		if hpGui then
			local hpPercent = math.clamp(1 - progress, 0, 1)
			local fill = hpGui:FindFirstChild("Background") and hpGui.Background:FindFirstChild("Fill")
			local label = hpGui:FindFirstChild("Label")
			if fill then
				fill.Size = UDim2.new(hpPercent, 0, 1, 0)
				fill.BackgroundColor3 = Color3.fromHSV(hpPercent * 0.33, 0.85, 0.95)
			end
			if label then
				label.Text = string.format("TARGET DUMMY • %d%%", math.ceil(hpPercent * 100))
			end
		end

		local flash = dummy:FindFirstChild("CombatFlash")
		if lunge > 0.85 then
			if not flash then
				local h = Instance.new("Highlight")
				h.Name = "CombatFlash"
				h.FillColor = Color3.fromRGB(255, 75, 75)
				h.FillTransparency = 0.3
				h.OutlineTransparency = 0.5
				h.Adornee = dummy
				h.Parent = dummy
			end
			if now - self._lastDamagePopupTime > 0.65 then
				self._lastDamagePopupTime = now
				local reward = (self._battle and self._battle.Reward) or 15
				spawnDamagePopup(self._battleFolder, string.format("-%d", reward), Vector3.new(0.5, 5.8, 8))
			end
		elseif flash then
			flash:Destroy()
		end
	end
	if fighter and fighter.PrimaryPart then
		fighter:PivotTo(CFrame.new(-6.5 + lunge * 4.2, 2.3 + lunge * 0.45, 8))
	end
end

function WorldController:Stop()
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
