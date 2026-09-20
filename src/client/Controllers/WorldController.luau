--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
	Muted = Color3.fromRGB(120, 140, 160),
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
	local mType = mutant.Type or mutant.Name or "Blob"
	local mTier = mutant.Tier or (if mType == "PlasmaBlob" then 3 elseif mType == "ToxicBlob" then 2 else 1)
	local isPlasma = mType == "PlasmaBlob" or mTier == 3
	local toxic = mType == "ToxicBlob" or mTier == 2
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
				Enum.Material.Neon
			)
			node.Shape = Enum.PartType.Cylinder
		end
		local halo = part(
			model,
			"PlasmaHalo",
			Vector3.new(3.2, 0.12, 3.2),
			at * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(120, 230, 255),
			Enum.Material.Neon
		)
		halo.Shape = Enum.PartType.Cylinder
	end

	-- Role visual accessories on player blobs
	local role = mutant.Role or "Striker"
	if role == "Striker" then
		-- Dual sharp combat horns / crest
		local hornColor = if isPlasma
			then Color3.fromRGB(255, 90, 150)
			elseif toxic then Color3.fromRGB(255, 170, 40)
			else Color3.fromRGB(255, 60, 80)
		for _, x in { -0.95, 0.95 } do
			local horn = part(
				model,
				"StrikerHorn",
				Vector3.new(0.35, 1.35, 0.35),
				at
					* CFrame.new(x, 1.5 + bodySize.Y * 0.4, -0.4)
					* CFrame.Angles(-0.35, 0, (if x < 0 then 1 else -1) * 0.35),
				hornColor,
				Enum.Material.Neon
			)
			horn.Shape = Enum.PartType.Cylinder
		end
	elseif role == "Guardian" then
		-- Heavy armored chest shield plate + glowing power core
		local shieldZ = -bodySize.Z * 0.48 - 0.1
		part(
			model,
			"GuardianShield",
			Vector3.new(2.6, 1.4, 0.35),
			at * CFrame.new(0, 1.35, shieldZ),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
		local shieldCore = part(
			model,
			"GuardianShieldCore",
			Vector3.new(0.65, 0.65, 0.42),
			at * CFrame.new(0, 1.35, shieldZ - 0.05),
			if isPlasma then Color3.fromRGB(130, 220, 255) elseif toxic then COLORS.Lime else COLORS.Cyan,
			Enum.Material.Neon
		)
		shieldCore.Shape = Enum.PartType.Ball
	elseif role == "Healer" then
		-- Floating emerald healing cross overhead
		local crossY = 1.5 + bodySize.Y * 0.5 + (if isPlasma then 0.9 else 0.65)
		part(
			model,
			"HealerCrossH",
			Vector3.new(1.1, 0.28, 0.22),
			at * CFrame.new(0, crossY, -0.15),
			Color3.fromRGB(60, 255, 140),
			Enum.Material.Neon
		)
		part(
			model,
			"HealerCrossV",
			Vector3.new(0.28, 1.1, 0.22),
			at * CFrame.new(0, crossY, -0.15),
			Color3.fromRGB(60, 255, 140),
			Enum.Material.Neon
		)
	elseif role == "Buffer" then
		-- Dual energy amplifier antennas with glowing booster spheres
		for _, x in { -1.1, 1.1 } do
			local antennaY = 1.5 + bodySize.Y * 0.42
			local stem = part(
				model,
				"BufferStem",
				Vector3.new(0.16, 1.0, 0.16),
				at * CFrame.new(x, antennaY, 0) * CFrame.Angles(0, 0, (if x < 0 then 1 else -1) * 0.3),
				COLORS.Ink,
				Enum.Material.SmoothPlastic
			)
			stem.Shape = Enum.PartType.Cylinder
			local orb = part(
				model,
				"BufferOrb",
				Vector3.new(0.5, 0.5, 0.5),
				at * CFrame.new(x * 1.25, antennaY + 0.6, 0),
				Color3.fromRGB(255, 215, 50),
				Enum.Material.Neon
			)
			orb.Shape = Enum.PartType.Ball
		end
	elseif role == "Controller" then
		-- Psionic crown triad hovering above forehead
		local crownY = 1.5 + bodySize.Y * 0.5 + 0.45
		for idx = -1, 1 do
			local node = part(
				model,
				"PsionicNode_" .. tostring(idx),
				Vector3.new(0.42, 0.42, 0.42),
				at * CFrame.new(idx * 0.85, crownY + math.abs(idx) * 0.18, -0.35),
				Color3.fromRGB(255, 110, 230),
				Enum.Material.Neon
			)
			node.Shape = Enum.PartType.Ball
		end
	end

	-- Ground energy base ring
	local baseRingColor = if isPlasma
		then Color3.fromRGB(150, 80, 255)
		elseif toxic then COLORS.Toxic
		else COLORS.Cyan
	local baseRing = part(
		model,
		"BaseRing",
		Vector3.new(0.08, bodySize.X + 0.6, bodySize.Z + 0.6),
		at * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2),
		baseRingColor,
		Enum.Material.Neon
	)
	baseRing.Shape = Enum.PartType.Cylinder

	local displayName = if isPlasma then "PLASMA BLOB" elseif toxic then "TOXIC BLOB" else "BLOB"
	local isCombat = mutant.CurrentHp ~= nil and mutant.MaxHp ~= nil

	if not isCombat then
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
	else
		model:SetAttribute("UnitId", mutant.Id)
		model:SetAttribute("CurrentHp", mutant.CurrentHp)
		model:SetAttribute("MaxHp", mutant.MaxHp)

		local combatGui = Instance.new("BillboardGui")
		combatGui.Name = "CombatUnitUI"
		combatGui.Size = UDim2.fromOffset(160, 44)
		combatGui.StudsOffset = Vector3.new(0, if isPlasma then 3.8 else 3.2, 0)
		combatGui.AlwaysOnTop = true
		combatGui.Parent = body

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = if isPlasma
			then Color3.fromRGB(170, 225, 255)
			elseif toxic then COLORS.Toxic
			else COLORS.Cyan
		nameLabel.Text = string.format(
			"[P] %s • Lv.%s (%s)",
			displayName,
			tostring(mutant.Level or 1),
			string.upper(role)
		)
		nameLabel.Parent = combatGui

		local hpBarBg = Instance.new("Frame")
		hpBarBg.Name = "HpBarBg"
		hpBarBg.Size = UDim2.new(1, -20, 0, 6)
		hpBarBg.Position = UDim2.new(0, 10, 0, 20)
		hpBarBg.BackgroundColor3 = COLORS.PanelSoft
		hpBarBg.Parent = combatGui
		addCorner(hpBarBg, 3)

		local hpPct = math.clamp(mutant.CurrentHp / math.max(1, mutant.MaxHp), 0, 1)
		local hpFill = Instance.new("Frame")
		hpFill.Name = "HpFill"
		hpFill.Size = UDim2.new(hpPct, 0, 1, 0)
		hpFill.BackgroundColor3 = if hpPct > 0.5
			then COLORS.Lime
			elseif hpPct > 0.25 then COLORS.Orange
			else COLORS.Red
		hpFill.Parent = hpBarBg
		addCorner(hpFill, 3)
	end

	model.Parent = parent
	return model
end

local function makeHologramPlaceholder(parent, mutant, at, order, isExpedition)
	local model = Instance.new("Model")
	model.Name = tostring(mutant.Id)
	model:SetAttribute("MutantId", mutant.Id)
	model:SetAttribute("Order", order or 1)
	model:SetAttribute("IsHologram", true)

	local ghostColor = if isExpedition then COLORS.Purple else COLORS.Cyan
	local ghost = part(
		model,
		"Ghost",
		Vector3.new(2.8, 2.3, 2.8),
		at * CFrame.new(0, 1.4, 0),
		ghostColor,
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
		if isExpedition then COLORS.Purple else COLORS.Orange,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = at * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local mType = mutant.Type or mutant.Name or "Blob"
	local displayName = if mType == "PlasmaBlob"
		then "PLASMA BLOB"
		elseif mType == "ToxicBlob" then "TOXIC BLOB"
		else "BLOB"
	local statusText = if isExpedition then "DEPLOYED (EXPEDITION)" else "IN TRAINING"
	local tagColor = if isExpedition then COLORS.Purple else COLORS.Orange
	labelOn(ghost, string.format("%s  •  %s", displayName, statusText), Vector3.new(0, 2.4, 0), tagColor)
	model.Parent = parent
	return model
end

local function makeEnemyUnit(parent, enemy, at, order)
	local model = Instance.new("Model")
	model.Name = tostring(enemy.Id)
	model:SetAttribute("EnemyId", enemy.Id)
	model:SetAttribute("UnitId", enemy.Id)
	model:SetAttribute("Order", order or 1)
	model:SetAttribute("IsEnemy", true)
	model:SetAttribute("CurrentHp", enemy.CurrentHp)
	model:SetAttribute("MaxHp", enemy.MaxHp)

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
	local body =
		part(model, "Body", bodySize, at * CFrame.new(0, 1.6, 0), bodyColor, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	model:SetAttribute("BaseX", body.Position.X)
	model:SetAttribute("BaseY", body.Position.Y)
	model:SetAttribute("BaseZ", body.Position.Z)
	model:SetAttribute("BaseSizeX", bodySize.X)
	model:SetAttribute("BaseSizeY", bodySize.Y)
	model:SetAttribute("BaseSizeZ", bodySize.Z)

	-- Eyes facing forward towards player squad (+Z relative to at)
	for index, x in { -0.58, 0.58 } do
		local eye = part(
			model,
			"Eye_" .. tostring(index),
			Vector3.new(0.52, 0.65, 0.3),
			at * CFrame.new(x, 1.95, 1.42),
			Color3.fromRGB(255, 60, 60),
			Enum.Material.Neon
		)
		eye.Shape = Enum.PartType.Ball
		local pupil = part(
			model,
			"Pupil_" .. tostring(index),
			Vector3.new(0.22, 0.32, 0.16),
			at * CFrame.new(x, 1.95, 1.58),
			Color3.fromRGB(25, 0, 0),
			Enum.Material.SmoothPlastic
		)
		pupil.Shape = Enum.PartType.Ball
	end

	-- Menacing horns or armor features based on enemy role
	if enemy.Role == "Striker" then
		for index, x in { -1.1, 1.1 } do
			local horn = part(
				model,
				"StrikerHorn",
				Vector3.new(1.4, 0.35, 0.35),
				at
					* CFrame.new(x, 2.9, 0.2)
					* CFrame.Angles(0, 0, (if x < 0 then 1 else -1) * 0.4 + math.pi / 2),
				bodyColor,
				Enum.Material.Neon
			)
			horn.Shape = Enum.PartType.Cylinder
		end
	elseif enemy.Role == "Guardian" then
		part(
			model,
			"GuardianShield",
			Vector3.new(3.8, 2.0, 0.4),
			at * CFrame.new(0, 1.5, 1.65),
			COLORS.Metal,
			Enum.Material.DiamondPlate
		)
	elseif enemy.Role == "Controller" then
		-- Psionic crown nodes
		for idx = -1, 1 do
			local node = part(
				model,
				"PsionicNode_" .. tostring(idx),
				Vector3.new(0.45, 0.45, 0.45),
				at * CFrame.new(idx * 0.9, 3.2 + math.abs(idx) * 0.2, 0.1),
				Color3.fromRGB(255, 120, 220),
				Enum.Material.Neon
			)
			node.Shape = Enum.PartType.Ball
		end
	elseif enemy.Role == "Support" then
		local crown = part(
			model,
			"SupportHalo",
			Vector3.new(0.08, 2.8, 2.8),
			at * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(80, 255, 160),
			Enum.Material.Neon
		)
		crown.Shape = Enum.PartType.Cylinder
	end

	-- Ground Base Ring
	local baseRing = part(
		model,
		"BaseRing",
		Vector3.new(0.08, 4.2, 4.2),
		at * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		bodyColor,
		Enum.Material.Neon
	)
	baseRing.Shape = Enum.PartType.Cylinder

	local hl = Instance.new("Highlight")
	hl.Name = "EnemyHighlight"
	hl.FillColor = bodyColor
	hl.FillTransparency = 0.75
	hl.OutlineColor = COLORS.Red
	hl.OutlineTransparency = 0.2
	hl.Adornee = model
	hl.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyUI"
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = COLORS.Red
	nameLabel.Text = string.format("[E] %s", enemy.Name)
	nameLabel.Parent = gui

	local hpBarBg = Instance.new("Frame")
	hpBarBg.Name = "HpBarBg"
	hpBarBg.Size = UDim2.new(1, -20, 0, 6)
	hpBarBg.Position = UDim2.new(0, 10, 0, 22)
	hpBarBg.BackgroundColor3 = COLORS.PanelSoft
	hpBarBg.Parent = gui
	addCorner(hpBarBg, 3)

	local hpPct = math.clamp((enemy.CurrentHp or 0) / math.max(1, enemy.MaxHp or 1), 0, 1)
	local hpFill = Instance.new("Frame")
	hpFill.Name = "HpFill"
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
	self._expeditionFolder = nil
	self._selectedCombatTargetId = nil
	self._currentExpeditionRoom = nil
	self._currentExpeditionId = nil
	self._lastCombatLogCount = nil
	self._combatCameraShake = 0
	self._inExpedition = false
	self._cameraYaw = 0
	self._cameraPitch = math.rad(28)
	self._cameraDistance = 14.5
	self._cameraFocusPoint = Vector3.new(20, 1.8, -3.5)
	self._isDraggingCamera = false
	self._inputConnections = {}
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
			{ x = -18, z = 22, color = COLORS.Toxic, label = "CRYO-CHAMBER 02" },
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

	-- Quantum Expedition Battle Arena Platform & Perimeter
	part(
		architecture,
		"ExpeditionArenaBase",
		Vector3.new(20, 0.45, 18),
		CFrame.new(20, 0.22, -3.5),
		COLORS.Panel,
		Enum.Material.DiamondPlate,
		true
	)
	part(
		architecture,
		"ExpeditionPlayerBorder",
		Vector3.new(20.2, 0.08, 0.35),
		CFrame.new(20, 0.46, 5.5),
		COLORS.Cyan,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"ExpeditionEnemyBorder",
		Vector3.new(20.2, 0.08, 0.35),
		CFrame.new(20, 0.46, -12.5),
		COLORS.Purple,
		Enum.Material.Neon,
		false
	)
	part(
		architecture,
		"ExpeditionCenterLine",
		Vector3.new(19.8, 0.04, 0.2),
		CFrame.new(20, 0.46, -3.5),
		COLORS.Muted,
		Enum.Material.Neon,
		false
	)
	for _, px in { 10, 30 } do
		for _, pz in { 5.5, -12.5 } do
			local pylon = part(
				architecture,
				"ArenaPylon",
				Vector3.new(0.6, 3.2, 0.6),
				CFrame.new(px, 1.6, pz),
				COLORS.DeepSlate,
				Enum.Material.Metal,
				true
			)
			local beacon = part(
				architecture,
				"ArenaPylonBeacon",
				Vector3.new(0.8, 0.8, 0.8),
				CFrame.new(px, 3.4, pz),
				if pz > 0 then COLORS.Cyan else COLORS.Purple,
				Enum.Material.Neon,
				false
			)
			beacon.Shape = Enum.PartType.Ball
			local pLight = Instance.new("PointLight")
			pLight.Color = if pz > 0 then COLORS.Cyan else COLORS.Purple
			pLight.Range = 9
			pLight.Brightness = 0.8
			pLight.Parent = beacon
		end
	end

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
		if self._inExpedition then
			local char = Players.LocalPlayer.Character
			if char then
				for _, p in char:GetDescendants() do
					if p:IsA("BasePart") or p:IsA("Decal") then
						p.LocalTransparencyModifier = 1
					end
				end
			end
			if self._camera then
				self._camera.CameraType = Enum.CameraType.Scriptable

				-- Smooth keyboard orbit / zoom when not typing in chat
				if not UserInputService:GetFocusedTextBox() then
					if
						UserInputService:IsKeyDown(Enum.KeyCode.A)
						or UserInputService:IsKeyDown(Enum.KeyCode.Left)
					then
						self._cameraYaw = (self._cameraYaw + 0.03) % (math.pi * 2)
					end
					if
						UserInputService:IsKeyDown(Enum.KeyCode.D)
						or UserInputService:IsKeyDown(Enum.KeyCode.Right)
					then
						self._cameraYaw = (self._cameraYaw - 0.03) % (math.pi * 2)
					end
					if
						UserInputService:IsKeyDown(Enum.KeyCode.W)
						or UserInputService:IsKeyDown(Enum.KeyCode.Up)
					then
						self._cameraDistance = math.clamp(self._cameraDistance - 0.2, 7, 28)
					end
					if
						UserInputService:IsKeyDown(Enum.KeyCode.S)
						or UserInputService:IsKeyDown(Enum.KeyCode.Down)
					then
						self._cameraDistance = math.clamp(self._cameraDistance + 0.2, 7, 28)
					end
				end

				-- Smooth drag orbit via GetMouseLocation
				if self._isDraggingCamera then
					local currentMouse = UserInputService:GetMouseLocation()
					if self._lastMousePos then
						local dx = currentMouse.X - self._lastMousePos.X
						local dy = currentMouse.Y - self._lastMousePos.Y
						if dx ~= 0 or dy ~= 0 then
							self._cameraYaw = (self._cameraYaw - dx * 0.005) % (math.pi * 2)
							self._cameraPitch =
								math.clamp(self._cameraPitch + dy * 0.004, math.rad(10), math.rad(75))
						end
					end
					self._lastMousePos = currentMouse
				end

				local focus = self._cameraFocusPoint or Vector3.new(20, 1.8, -3.5)
				local dist = self._cameraDistance or 14.5
				local pitch = self._cameraPitch or math.rad(28)
				local yaw = self._cameraYaw or 0

				local hDist = dist * math.cos(pitch)
				local vDist = dist * math.sin(pitch)
				local offsetX = hDist * math.sin(yaw)
				local offsetZ = hDist * math.cos(yaw)

				local camPos = focus + Vector3.new(offsetX, vDist, offsetZ)

				if self._combatCameraShake and self._combatCameraShake > 0 then
					local shake = (math.random() - 0.5) * self._combatCameraShake * 1.5
					camPos += Vector3.new(shake, shake * 0.5, 0)
					self._combatCameraShake = math.max(0, self._combatCameraShake - 0.03)
				end
				self._camera.CFrame = CFrame.lookAt(camPos, focus)
			end
		end
	end)

	local inputConn1 = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not self._inExpedition then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
		then
			self._isDraggingCamera = true
			self._lastMousePos = UserInputService:GetMouseLocation()
		elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
			self._isDraggingCamera = true
			self._lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.R and not gameProcessed then
			self:ResetCombatCamera()
		end
	end)

	local inputConn2 = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._isDraggingCamera = false
			self._lastMousePos = nil
		end
	end)

	local inputConn3 = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not self._inExpedition then
			return
		end
		if
			(
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			) and self._isDraggingCamera
		then
			local delta = input.Delta
			if delta.X ~= 0 or delta.Y ~= 0 then
				self._cameraYaw = (self._cameraYaw - delta.X * 0.005) % (math.pi * 2)
				self._cameraPitch =
					math.clamp(self._cameraPitch + delta.Y * 0.004, math.rad(10), math.rad(75))
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			self._cameraDistance = math.clamp(self._cameraDistance - input.Position.Z * 1.5, 7, 28)
		end
	end)

	table.insert(self._inputConnections, inputConn1)
	table.insert(self._inputConnections, inputConn2)
	table.insert(self._inputConnections, inputConn3)
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
					if string.sub(u.Id, 1, 2) == "p_" then
						expeditionMutantIds[string.sub(u.Id, 3)] = u
					end
				end
			end
		end
	end

	self:_clear(self._display)
	for index, mutant in snapshot.Mutants or {} do
		if index <= 6 then
			local padCFrame = CFrame.new(-13 + (index - 1) * 5.1, 0.5, 3)
			local model
			local isExpMutant = expeditionMutantIds[mutant.Id] ~= nil
				or expeditionMutantIds["p_" .. mutant.Id] ~= nil
			if mutant.Id == battlingMutantId or isExpMutant then
				model = makeHologramPlaceholder(self._display, mutant, padCFrame, index, isExpMutant)
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

	local wasInExpedition = self._inExpedition
	self._inExpedition = inExpedition

	if inExpedition and not wasInExpedition then
		self:ResetCombatCamera()
	elseif not inExpedition and wasInExpedition then
		local char = Players.LocalPlayer.Character
		if char then
			for _, p in char:GetDescendants() do
				if p:IsA("BasePart") or p:IsA("Decal") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
		if self._camera then
			self._camera.CameraType = Enum.CameraType.Custom
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
		if snapshot.Expedition and snapshot.Expedition.InCombat and snapshot.Expedition.CurrentCombat then
			local combat = snapshot.Expedition.CurrentCombat
			local currentRoom = snapshot.Expedition.CurrentRoomIndex
			local expId = snapshot.Expedition.Id or "exp"
			local isNewRoom = self._currentExpeditionRoom ~= currentRoom or self._currentExpeditionId ~= expId

			if isNewRoom then
				self._currentExpeditionRoom = currentRoom
				self._currentExpeditionId = expId
				self._lastCombatLogCount = #(combat.Log or {})
				self:_rebuildExpeditionModels(combat)
			else
				self:_updateExpeditionModels(combat)
				local log = combat.Log or {}
				if self._lastCombatLogCount and #log > self._lastCombatLogCount then
					for i = self._lastCombatLogCount + 1, #log do
						self:_playCombatAction(log[i])
					end
					self._lastCombatLogCount = #log
				elseif self._lastCombatLogCount == nil then
					self._lastCombatLogCount = #log
				end
			end
		else
			self._currentExpeditionRoom = nil
			self._currentExpeditionId = nil
			self._lastCombatLogCount = nil
			self:_clear(self._expeditionFolder)
		end
	end
end

local COMBAT_SOUNDS = {
	Hit = "rbxasset://sounds/action_falling_feather.mp3",
	Crit = "rbxasset://sounds/snap.wav",
	Heal = "rbxasset://sounds/electronicpingshort.wav",
	Whoosh = "rbxasset://sounds/action_jump.mp3",
	Battle = "rbxasset://sounds/impact_water.mp3",
}

function WorldController:_playSound(soundName)
	local id = COMBAT_SOUNDS[soundName]
	if not id then
		return
	end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.6
		sound.Parent = game:GetService("SoundService")
		sound.PlayOnRemove = true
		sound:Destroy()
	end)
end

function WorldController:_isMatchingUnit(model, unitId)
	if not model or not unitId then
		return false
	end
	local mName = model.Name
	local uId = model:GetAttribute("UnitId")
	local eId = model:GetAttribute("EnemyId")
	if mName == unitId or uId == unitId or eId == unitId then
		return true
	end
	if string.sub(unitId, 1, 2) == "p_" then
		local rawId = string.sub(unitId, 3)
		if mName == rawId or uId == rawId or eId == rawId then
			return true
		end
	end
	if uId and string.sub(tostring(uId), 1, 2) == "p_" then
		local rawId = string.sub(tostring(uId), 3)
		if rawId == unitId then
			return true
		end
	end
	return false
end

function WorldController:_findCombatUnitModel(unitId)
	if not self._expeditionFolder or not unitId then
		return nil
	end
	for _, m in self._expeditionFolder:GetChildren() do
		if self:_isMatchingUnit(m, unitId) then
			return m
		end
	end
	return nil
end

function WorldController:SetCombatTarget(targetId)
	self._selectedCombatTargetId = targetId
	self:_updateCombatTargetHighlights()
end

function WorldController:_updateCombatTargetHighlights()
	if not self._expeditionFolder then
		return
	end
	for _, model in self._expeditionFolder:GetChildren() do
		local isTarget = model:GetAttribute("IsEnemy") == true
			and self:_isMatchingUnit(model, self._selectedCombatTargetId)
		local hl = model:FindFirstChildOfClass("Highlight")
		local reticle = model:FindFirstChild("TargetReticle", true)
		if isTarget then
			if hl then
				hl.OutlineColor = Color3.fromRGB(255, 230, 60)
				hl.OutlineTransparency = 0
			end
			if not reticle then
				local body = model.PrimaryPart or model:FindFirstChild("Body")
				if body then
					local gui = Instance.new("BillboardGui")
					gui.Name = "TargetReticle"
					gui.Size = UDim2.fromOffset(120, 26)
					gui.StudsOffset = Vector3.new(0, 5.0, 0)
					gui.AlwaysOnTop = true
					gui.Parent = body

					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.fromScale(1, 1)
					lbl.BackgroundTransparency = 1
					lbl.Font = Enum.Font.GothamBlack
					lbl.TextSize = 13
					lbl.TextColor3 = Color3.fromRGB(255, 225, 60)
					lbl.TextStrokeTransparency = 0
					lbl.TextStrokeColor3 = Color3.fromRGB(30, 20, 0)
					lbl.Text = "🎯 TARGET"
					lbl.Parent = gui
				end
			end
		else
			if hl then
				hl.OutlineColor = if model:GetAttribute("IsEnemy") then COLORS.Red else COLORS.Cyan
				hl.OutlineTransparency = 0.3
			end
			if reticle then
				reticle:Destroy()
			end
		end
	end
end

function WorldController:_updateActiveTurnIndicator(currentTurnUnitId)
	if not self._expeditionFolder then
		return
	end
	for _, model in self._expeditionFolder:GetChildren() do
		local isTurn = self:_isMatchingUnit(model, currentTurnUnitId)
		local body = model.PrimaryPart or model:FindFirstChild("Body")
		local turnRing = model:FindFirstChild("ActiveTurnRing")
		local turnMarker = model:FindFirstChild("TurnMarker")
		if isTurn and body then
			local isEnemy = model:GetAttribute("IsEnemy") == true
			local ringColor = if isEnemy then COLORS.Orange else COLORS.Lime
			if not turnRing then
				local ring = part(
					model,
					"ActiveTurnRing",
					Vector3.new(0.08, 4.6, 4.6),
					CFrame.new(body.Position.X, 0.44, body.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
					ringColor,
					Enum.Material.Neon,
					false
				)
				ring.Shape = Enum.PartType.Cylinder
			end
			if not turnMarker then
				local gui = Instance.new("BillboardGui")
				gui.Name = "TurnMarker"
				gui.Size = UDim2.fromOffset(100, 24)
				gui.StudsOffset = Vector3.new(0, 4.8, 0)
				gui.AlwaysOnTop = true
				gui.Parent = body

				local lbl = Instance.new("TextLabel")
				lbl.Name = "TurnLabel"
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamBlack
				lbl.TextSize = 13
				lbl.TextColor3 = ringColor
				lbl.TextStrokeTransparency = 0
				lbl.TextStrokeColor3 = Color3.fromRGB(15, 15, 15)
				lbl.Text = "▼ ACTING"
				lbl.Parent = gui
			end
		else
			if turnRing then
				turnRing:Destroy()
			end
			if turnMarker then
				turnMarker:Destroy()
			end
		end
	end
end

function WorldController:_spawnFloatingCombatText(position, text, color, isCrit)
	local popupPart = Instance.new("Part")
	popupPart.Name = "DamagePopup"
	popupPart.Transparency = 1
	popupPart.CanCollide = false
	popupPart.Anchored = true
	popupPart.Size = Vector3.new(1, 1, 1)
	popupPart.Position = position + Vector3.new(0, 2.8, 0)
	popupPart.Parent = self._root

	local gui = Instance.new("BillboardGui")
	gui.Size = if isCrit then UDim2.fromOffset(200, 55) else UDim2.fromOffset(150, 42)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.Parent = popupPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if isCrit then 22 else 17
	label.TextColor3 = color or Color3.fromRGB(255, 200, 50)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	label.Text = text
	label.Parent = gui

	task.spawn(function()
		local duration = 0.85
		local tStart = os.clock()
		local startY = popupPart.Position.Y
		while true do
			local elapsed = os.clock() - tStart
			local alpha = math.clamp(elapsed / duration, 0, 1)
			popupPart.Position = Vector3.new(popupPart.Position.X, startY + alpha * 3.2, popupPart.Position.Z)
			label.TextTransparency = alpha * alpha
			label.TextStrokeTransparency = alpha * alpha
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		popupPart:Destroy()
	end)
end

function WorldController:_spawnImpactVFX(position, color)
	local shock = Instance.new("Part")
	shock.Name = "ImpactFlash"
	shock.Shape = Enum.PartType.Ball
	shock.Size = Vector3.new(0.5, 0.5, 0.5)
	shock.Color = color or COLORS.Orange
	shock.Material = Enum.Material.Neon
	shock.CanCollide = false
	shock.Anchored = true
	shock.Position = position
	shock.Parent = self._root

	local light = Instance.new("PointLight")
	light.Color = color or COLORS.Orange
	light.Range = 10
	light.Brightness = 3.0
	light.Parent = shock

	task.spawn(function()
		local duration = 0.22
		local tStart = os.clock()
		while true do
			local elapsed = os.clock() - tStart
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local scale = 0.5 + alpha * 3.5
			shock.Size = Vector3.new(scale, scale, scale)
			shock.Transparency = alpha
			light.Brightness = (1 - alpha) * 3.0
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		shock:Destroy()
	end)
end

function WorldController:_flinchTarget(targetModel, pushDir)
	local primary = targetModel.PrimaryPart or targetModel:FindFirstChild("Body")
	if not primary then
		return
	end
	local basePos = Vector3.new(
		targetModel:GetAttribute("BaseX") or primary.Position.X,
		targetModel:GetAttribute("BaseY") or primary.Position.Y,
		targetModel:GetAttribute("BaseZ") or primary.Position.Z
	)
	local hl = targetModel:FindFirstChildOfClass("Highlight")
	local oldFill = hl and hl.FillColor
	local oldFillTrans = hl and hl.FillTransparency
	if hl then
		hl.FillColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.1
	end
	targetModel:SetAttribute("IsActionAnimating", true)
	task.spawn(function()
		local flinchOffset = (pushDir or Vector3.new(0, 0, 1)) * 1.3
		targetModel:PivotTo(CFrame.new(basePos + flinchOffset))
		task.wait(0.08)
		if hl then
			hl.FillColor = oldFill or COLORS.Red
			hl.FillTransparency = oldFillTrans or 0.65
		end
		local tStart = os.clock()
		while true do
			local elapsed = os.clock() - tStart
			local alpha = math.clamp(elapsed / 0.15, 0, 1)
			local p = (basePos + flinchOffset):Lerp(basePos, alpha)
			targetModel:PivotTo(CFrame.new(p))
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		targetModel:PivotTo(CFrame.new(basePos))
		targetModel:SetAttribute("IsActionAnimating", nil)
	end)
end

function WorldController:_fireElementalProjectile(startPos, endPos, color)
	local proj = Instance.new("Part")
	proj.Name = "CombatProjectile"
	proj.Shape = Enum.PartType.Ball
	proj.Size = Vector3.new(1.0, 1.0, 1.0)
	proj.Color = color
	proj.Material = Enum.Material.Neon
	proj.CanCollide = false
	proj.Anchored = true
	proj.Position = startPos
	proj.Parent = self._root

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 2.0
	light.Parent = proj

	local flyDuration = 0.22
	local tStart = os.clock()
	while true do
		local elapsed = os.clock() - tStart
		local alpha = math.clamp(elapsed / flyDuration, 0, 1)
		proj.Position = startPos:Lerp(endPos, alpha)
		if alpha >= 1 then
			break
		end
		task.wait()
	end
	proj:Destroy()
end

function WorldController:_playDefeatAnimation(model)
	if model:GetAttribute("IsDying") then
		return
	end
	model:SetAttribute("IsDying", true)
	local primary = model.PrimaryPart or model:FindFirstChild("Body")
	local basePos = primary and primary.Position or Vector3.new(0, 0, 0)

	task.spawn(function()
		self:_spawnImpactVFX(basePos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 60, 60))
		local tStart = os.clock()
		local duration = 0.45
		local origSize = primary and primary.Size or Vector3.new(3, 3, 3)
		while true do
			local elapsed = os.clock() - tStart
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local scale = math.max(0.05, 1 - alpha)
			if primary then
				primary.Size = origSize * scale
				primary.Transparency = alpha
			end
			for _, desc in model:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Transparency = alpha
				elseif desc:IsA("BillboardGui") then
					desc.Enabled = false
				end
			end
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		model:Destroy()
	end)
end

function WorldController:_rebuildExpeditionModels(combat)
	self:_clear(self._expeditionFolder)
	if not combat then
		return
	end

	-- Living Enemies
	local livingEnemies = {}
	if combat.EnemyTeam and combat.EnemyTeam.Active then
		for _, enemy in combat.EnemyTeam.Active do
			if (enemy.IsAlive ~= false) and enemy.CurrentHp and enemy.CurrentHp > 0 then
				table.insert(livingEnemies, enemy)
			end
		end
	end
	local eCount = #livingEnemies
	for i, enemy in ipairs(livingEnemies) do
		local offsetX = (i - (eCount + 1) / 2) * 5.0
		local offsetZ = if i == 2 and eCount == 3 then -9.4 else -8.8
		-- Placed facing +Z towards player squad
		local at = CFrame.new(20 + offsetX, 0.4, offsetZ)
		makeEnemyUnit(self._expeditionFolder, enemy, at, i)
	end

	-- Living Player Squad
	local livingPlayers = {}
	if combat.PlayerTeam and combat.PlayerTeam.Active then
		for _, p in combat.PlayerTeam.Active do
			if p.IsAlive ~= false and p.CurrentHp and p.CurrentHp > 0 then
				table.insert(livingPlayers, p)
			end
		end
	end
	local pCount = #livingPlayers
	for i, p in ipairs(livingPlayers) do
		local offsetX = (i - (pCount + 1) / 2) * 5.0
		local offsetZ = if i == 2 and pCount == 3 then 1.2 else 2.2
		-- Placed facing -Z towards enemies
		local at = CFrame.new(20 + offsetX, 0.4, offsetZ)
		makeBlob(self._expeditionFolder, p, at, i)
	end

	self:_updateActiveTurnIndicator(combat.CurrentTurnUnitId)
	self:_updateCombatTargetHighlights()
end

function WorldController:_updateExpeditionModels(combat)
	if not combat or not self._expeditionFolder then
		return
	end

	-- Update player team units
	if combat.PlayerTeam and combat.PlayerTeam.Active then
		for _, p in combat.PlayerTeam.Active do
			local model = self:_findCombatUnitModel(p.Id)
			if model then
				model:SetAttribute("CurrentHp", p.CurrentHp)
				local hpFill = model:FindFirstChild("HpFill", true)
				if hpFill and hpFill:IsA("Frame") then
					local pct = math.clamp((p.CurrentHp or 0) / math.max(1, p.MaxHp or 1), 0, 1)
					hpFill.Size = UDim2.new(pct, 0, 1, 0)
					hpFill.BackgroundColor3 = if pct > 0.5
						then COLORS.Lime
						elseif pct > 0.25 then COLORS.Orange
						else COLORS.Red
				end
				if p.CurrentHp <= 0 and not model:GetAttribute("IsDying") then
					self:_playDefeatAnimation(model)
				end
			end
		end
	end

	-- Update enemy team units
	if combat.EnemyTeam and combat.EnemyTeam.Active then
		for _, enemy in combat.EnemyTeam.Active do
			local model = self:_findCombatUnitModel(enemy.Id)
			if model then
				model:SetAttribute("CurrentHp", enemy.CurrentHp)
				local hpFill = model:FindFirstChild("HpFill", true)
				if hpFill and hpFill:IsA("Frame") then
					local pct = math.clamp((enemy.CurrentHp or 0) / math.max(1, enemy.MaxHp or 1), 0, 1)
					hpFill.Size = UDim2.new(pct, 0, 1, 0)
					hpFill.BackgroundColor3 = if pct > 0.5
						then COLORS.Lime
						elseif pct > 0.25 then COLORS.Orange
						else COLORS.Red
				end
				if enemy.CurrentHp <= 0 and not model:GetAttribute("IsDying") then
					self:_playDefeatAnimation(model)
				end
			end
		end
	end

	self:_updateActiveTurnIndicator(combat.CurrentTurnUnitId)
	self:_updateCombatTargetHighlights()
end

function WorldController:_playCombatAction(entry)
	if not entry then
		return
	end
	local actorModel = self:_findCombatUnitModel(entry.ActorId)
	local targetModel = entry.TargetId and self:_findCombatUnitModel(entry.TargetId)

	if not actorModel then
		if targetModel and entry.Damage and entry.Damage > 0 then
			local tPrimary = targetModel.PrimaryPart or targetModel:FindFirstChild("Body")
			if tPrimary then
				self:_spawnFloatingCombatText(
					tPrimary.Position,
					"-" .. tostring(entry.Damage),
					COLORS.Orange,
					entry.IsCritical
				)
			end
		end
		return
	end

	local actorPrimary = actorModel.PrimaryPart or actorModel:FindFirstChild("Body")
	if not actorPrimary then
		return
	end

	local actorBasePos = Vector3.new(
		actorModel:GetAttribute("BaseX") or actorPrimary.Position.X,
		actorModel:GetAttribute("BaseY") or actorPrimary.Position.Y,
		actorModel:GetAttribute("BaseZ") or actorPrimary.Position.Z
	)

	if entry.ActionType == "Basic" and targetModel then
		local targetPrimary = targetModel.PrimaryPart or targetModel:FindFirstChild("Body")
		if not targetPrimary then
			return
		end

		local targetBasePos = Vector3.new(
			targetModel:GetAttribute("BaseX") or targetPrimary.Position.X,
			targetModel:GetAttribute("BaseY") or targetPrimary.Position.Y,
			targetModel:GetAttribute("BaseZ") or targetPrimary.Position.Z
		)

		actorModel:SetAttribute("IsActionAnimating", true)
		task.spawn(function()
			local dir = (targetBasePos - actorBasePos)
			local lungeTarget = targetBasePos - dir.Unit * 2.5
			local lungeDuration = 0.22
			local tStart = os.clock()

			while true do
				local elapsed = os.clock() - tStart
				local alpha = math.clamp(elapsed / lungeDuration, 0, 1)
				local arcY = math.sin(alpha * math.pi) * 2.2
				local curPos = actorBasePos:Lerp(lungeTarget, alpha) + Vector3.new(0, arcY, 0)
				actorModel:PivotTo(CFrame.new(curPos))
				if alpha >= 1 then
					break
				end
				task.wait()
			end

			-- IMPACT
			self:_playSound("Hit")
			if entry.IsCritical then
				self:_playSound("Crit")
				self._combatCameraShake = 0.35
			end

			self:_spawnImpactVFX(
				targetBasePos + Vector3.new(0, 1.4, 0),
				if entry.IsCritical then COLORS.Red else COLORS.Orange
			)
			self:_flinchTarget(targetModel, dir.Unit)

			if entry.Damage and entry.Damage > 0 then
				local text = if entry.IsCritical then "💥 CRIT! -" .. entry.Damage else "-" .. entry.Damage
				local color = if entry.IsCritical
					then Color3.fromRGB(255, 60, 60)
					else Color3.fromRGB(255, 200, 50)
				self:_spawnFloatingCombatText(targetBasePos, text, color, entry.IsCritical)
			end

			-- Return
			local returnDuration = 0.18
			local tRet = os.clock()
			while true do
				local elapsed = os.clock() - tRet
				local alpha = math.clamp(elapsed / returnDuration, 0, 1)
				local retArc = math.sin(alpha * math.pi) * 0.8
				local curPos = lungeTarget:Lerp(actorBasePos, alpha) + Vector3.new(0, retArc, 0)
				actorModel:PivotTo(CFrame.new(curPos))
				if alpha >= 1 then
					break
				end
				task.wait()
			end
			actorModel:PivotTo(CFrame.new(actorBasePos))
			actorModel:SetAttribute("IsActionAnimating", nil)
		end)
	elseif
		(entry.ActionType == "RoleSkill" or entry.ActionType == "Ultimate")
		and targetModel
		and entry.Damage
		and entry.Damage > 0
	then
		local targetPrimary = targetModel.PrimaryPart or targetModel:FindFirstChild("Body")
		if not targetPrimary then
			return
		end

		local targetBasePos = Vector3.new(
			targetModel:GetAttribute("BaseX") or targetPrimary.Position.X,
			targetModel:GetAttribute("BaseY") or targetPrimary.Position.Y,
			targetModel:GetAttribute("BaseZ") or targetPrimary.Position.Z
		)

		actorModel:SetAttribute("IsActionAnimating", true)
		task.spawn(function()
			spawnLightRing(self._root, actorBasePos + Vector3.new(0, 0.2, 0), COLORS.Purple, 4.8, 0.3)
			task.wait(0.12)

			self:_fireElementalProjectile(
				actorBasePos + Vector3.new(0, 1.5, 0),
				targetBasePos + Vector3.new(0, 1.5, 0),
				COLORS.Purple
			)

			self:_playSound("Hit")
			if entry.IsCritical then
				self:_playSound("Crit")
				self._combatCameraShake = 0.4
			end

			self:_spawnImpactVFX(targetBasePos + Vector3.new(0, 1.4, 0), COLORS.Purple)
			self:_flinchTarget(targetModel, (targetBasePos - actorBasePos).Unit)

			local text = if entry.IsCritical
				then "💥 "
					.. (if entry.ActionType == "Ultimate" then "ULTIMATE! -" else "CRIT! -")
					.. entry.Damage
				else "-" .. entry.Damage
			self:_spawnFloatingCombatText(targetBasePos, text, Color3.fromRGB(255, 90, 220), true)

			if string.find(string.lower(entry.Message or ""), "stun") then
				self:_spawnFloatingCombatText(
					targetBasePos + Vector3.new(0, 1.8, 0),
					"💫 STUNNED!",
					Color3.fromRGB(200, 100, 255),
					false
				)
			end

			actorModel:SetAttribute("IsActionAnimating", nil)
		end)
	elseif entry.Heal and entry.Heal > 0 and targetModel then
		local targetPrimary = targetModel.PrimaryPart or targetModel:FindFirstChild("Body")
		local targetBasePos = targetPrimary and targetPrimary.Position or actorBasePos
		task.spawn(function()
			self:_playSound("Heal")
			spawnLightRing(self._root, actorBasePos + Vector3.new(0, 0.2, 0), COLORS.Lime, 5.0, 0.4)
			spawnLightRing(self._root, targetBasePos + Vector3.new(0, 0.2, 0), COLORS.Lime, 5.0, 0.5)
			self:_spawnFloatingCombatText(
				targetBasePos,
				"💚 +" .. entry.Heal .. " HP",
				Color3.fromRGB(80, 255, 120),
				false
			)
		end)
	elseif
		entry.ActionType == "RoleSkill"
		and (
			string.find(string.lower(entry.Message or ""), "boost")
			or string.find(string.lower(entry.Message or ""), "surge")
		)
	then
		task.spawn(function()
			self:_playSound("Whoosh")
			spawnLightRing(self._root, actorBasePos + Vector3.new(0, 0.2, 0), COLORS.Cyan, 6.5, 0.5)
			self:_spawnFloatingCombatText(actorBasePos, "⚔️ +35% ATK (TEAM)", COLORS.Cyan, true)
		end)
	end
end

function WorldController:_animateBlobs()
	if not self._display then
		return
	end
	local now = workspace:GetServerTimeNow()
	local folders = { self._display }
	if self._expeditionFolder then
		table.insert(folders, self._expeditionFolder)
	end

	for _, folder in ipairs(folders) do
		for _, child in folder:GetChildren() do
			if child:GetAttribute("IsActionAnimating") or child:GetAttribute("IsDying") then
				continue
			end
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
						eye.Size = if isBlink
							then Vector3.new(0.5, 0.08, 0.28)
							else Vector3.new(0.5, 0.65, 0.28)
					end
					if pupil and pupil:IsA("BasePart") then
						pupil.Transparency = if isBlink then 1 else 0
					end
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

function WorldController:ResetCombatCamera()
	self._cameraYaw = 0
	self._cameraPitch = math.rad(28)
	self._cameraDistance = 14.5
end

function WorldController:SetCombatCameraOrbit(yaw, pitch, distance)
	if yaw ~= nil then
		self._cameraYaw = yaw % (math.pi * 2)
	end
	if pitch ~= nil then
		self._cameraPitch = math.clamp(pitch, math.rad(10), math.rad(75))
	end
	if distance ~= nil then
		self._cameraDistance = math.clamp(distance, 7, 28)
	end
end

function WorldController:GetCombatCameraOrbit()
	return {
		Yaw = self._cameraYaw,
		Pitch = self._cameraPitch,
		Distance = self._cameraDistance,
	}
end

function WorldController:Stop()
	self:_completeMergeAnimation()
	if self._inputConnections then
		for _, conn in ipairs(self._inputConnections) do
			if conn and conn.Disconnect then
				conn:Disconnect()
			end
		end
		self._inputConnections = {}
	end
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
