--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = ReplicatedStorage:WaitForChild("MutantLab")
local shared = root:WaitForChild("Shared")
local ElementMatrix = require(shared:WaitForChild("Combat"):WaitForChild("ElementMatrix"))

local CombatUI = {}
CombatUI.__index = CombatUI

local COLORS = {
	Panel = Color3.fromRGB(16, 23, 31),
	PanelSoft = Color3.fromRGB(27, 37, 47),
	Card = Color3.fromRGB(37, 49, 60),
	Text = Color3.fromRGB(239, 247, 245),
	Muted = Color3.fromRGB(157, 175, 180),
	Cyan = Color3.fromRGB(69, 224, 205),
	Lime = Color3.fromRGB(166, 244, 83),
	Purple = Color3.fromRGB(174, 91, 255),
	Orange = Color3.fromRGB(255, 164, 73),
	Red = Color3.fromRGB(241, 91, 102),
	Gold = Color3.fromRGB(255, 215, 0),
	Disabled = Color3.fromRGB(69, 78, 84),
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

function CombatUI.new(parentGui, callbacks)
	local self = setmetatable({}, CombatUI)
	self.ParentGui = parentGui
	self.Callbacks = callbacks or {}
	self.SelectedTargetId = nil
	self.SelectedAbilityType = "Basic"

	-- Main Combat HUD Frame
	local container = Instance.new("Frame")
	container.Name = "CombatHUD"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parentGui
	self.Container = container

	-- Top Bar: Room Title & Timeline
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, -40, 0, 90)
	topBar.Position = UDim2.new(0, 20, 0, 10)
	topBar.BackgroundColor3 = COLORS.Panel
	topBar.Parent = container
	addCorner(topBar, 10)
	addStroke(topBar, COLORS.PanelSoft, 2)

	local roomTitle = Instance.new("TextLabel")
	roomTitle.Name = "RoomTitle"
	roomTitle.Size = UDim2.new(1, -290, 0, 24)
	roomTitle.Position = UDim2.new(0, 10, 0, 6)
	roomTitle.BackgroundTransparency = 1
	roomTitle.Font = Enum.Font.GothamBold
	roomTitle.TextSize = 14
	roomTitle.TextColor3 = COLORS.Cyan
	roomTitle.TextXAlignment = Enum.TextXAlignment.Left
	roomTitle.Text = "EXPEDITION ACTIVE"
	roomTitle.Parent = topBar
	self.RoomTitle = roomTitle

	-- Orbital Camera Hint & Reset Badge
	local camHint = Instance.new("TextButton")
	camHint.Name = "CameraControlBadge"
	camHint.Size = UDim2.new(0, 260, 0, 22)
	camHint.Position = UDim2.new(1, -270, 0, 7)
	camHint.BackgroundColor3 = COLORS.PanelSoft
	camHint.BackgroundTransparency = 0.4
	camHint.Font = Enum.Font.GothamMedium
	camHint.TextSize = 11
	camHint.TextColor3 = COLORS.Muted
	camHint.Text = "🖱️ RMB Orbit • 📜 Zoom • [R] Reset"
	camHint.Parent = topBar
	addCorner(camHint, 5)

	camHint.MouseButton1Click:Connect(function()
		if self.Callbacks.OnResetCamera then
			self.Callbacks.OnResetCamera()
		end
	end)

	-- Timeline List
	local timeline = Instance.new("ScrollingFrame")
	timeline.Name = "Timeline"
	timeline.Size = UDim2.new(1, -20, 0, 48)
	timeline.Position = UDim2.new(0, 10, 0, 34)
	timeline.BackgroundTransparency = 1
	timeline.ScrollBarThickness = 2
	timeline.CanvasSize = UDim2.new(2, 0, 0, 0)
	timeline.Parent = topBar
	self.Timeline = timeline

	local timelineLayout = Instance.new("UIListLayout")
	timelineLayout.FillDirection = Enum.FillDirection.Horizontal
	timelineLayout.Padding = UDim.new(0, 8)
	timelineLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	timelineLayout.Parent = timeline

	-- Center Area: Target Selection Panels (Living Enemies)
	local targetsFrame = Instance.new("Frame")
	targetsFrame.Name = "TargetsFrame"
	targetsFrame.Size = UDim2.new(0, 500, 0, 120)
	targetsFrame.Position = UDim2.new(0.5, -250, 0, 110)
	targetsFrame.BackgroundTransparency = 1
	targetsFrame.Parent = container
	self.TargetsFrame = targetsFrame

	local targetsLayout = Instance.new("UIListLayout")
	targetsLayout.FillDirection = Enum.FillDirection.Horizontal
	targetsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	targetsLayout.Padding = UDim.new(0, 12)
	targetsLayout.Parent = targetsFrame

	-- Bottom Command Deck: Energy & Abilities
	local commandDeck = Instance.new("Frame")
	commandDeck.Name = "CommandDeck"
	commandDeck.Size = UDim2.new(1, -40, 0, 120)
	commandDeck.Position = UDim2.new(0, 20, 1, -130)
	commandDeck.BackgroundColor3 = COLORS.Panel
	commandDeck.Parent = container
	addCorner(commandDeck, 10)
	addStroke(commandDeck, COLORS.PanelSoft, 2)
	self.CommandDeck = commandDeck

	-- Energy Display
	local energyHeader = Instance.new("TextLabel")
	energyHeader.Name = "EnergyHeader"
	energyHeader.Size = UDim2.new(0, 200, 0, 20)
	energyHeader.Position = UDim2.new(0, 16, 0, 10)
	energyHeader.BackgroundTransparency = 1
	energyHeader.Font = Enum.Font.GothamBold
	energyHeader.TextSize = 13
	energyHeader.TextColor3 = COLORS.Gold
	energyHeader.TextXAlignment = Enum.TextXAlignment.Left
	energyHeader.Text = "TEAM ENERGY: 0 / 10"
	energyHeader.Parent = commandDeck
	self.EnergyHeader = energyHeader

	local energyCells = Instance.new("Frame")
	energyCells.Name = "EnergyCells"
	energyCells.Size = UDim2.new(0, 240, 0, 14)
	energyCells.Position = UDim2.new(0, 16, 0, 32)
	energyCells.BackgroundTransparency = 1
	energyCells.Parent = commandDeck
	self.EnergyCells = energyCells

	local energyLayout = Instance.new("UIListLayout")
	energyLayout.FillDirection = Enum.FillDirection.Horizontal
	energyLayout.Padding = UDim.new(0, 4)
	energyLayout.Parent = energyCells

	-- Abilities Buttons Container
	local abilitiesContainer = Instance.new("Frame")
	abilitiesContainer.Name = "AbilitiesContainer"
	abilitiesContainer.Size = UDim2.new(1, -280, 0, 56)
	abilitiesContainer.Position = UDim2.new(0, 260, 0, 10)
	abilitiesContainer.BackgroundTransparency = 1
	abilitiesContainer.Parent = commandDeck
	self.AbilitiesContainer = abilitiesContainer

	local abilitiesLayout = Instance.new("UIListLayout")
	abilitiesLayout.FillDirection = Enum.FillDirection.Horizontal
	abilitiesLayout.Padding = UDim.new(0, 10)
	abilitiesLayout.Parent = abilitiesContainer

	-- Action Button (Execute)
	local executeBtn = Instance.new("TextButton")
	executeBtn.Name = "ExecuteButton"
	executeBtn.Size = UDim2.new(0, 180, 0, 36)
	executeBtn.Position = UDim2.new(1, -200, 1, -44)
	executeBtn.BackgroundColor3 = COLORS.Cyan
	executeBtn.Font = Enum.Font.GothamBold
	executeBtn.TextSize = 14
	executeBtn.TextColor3 = COLORS.Panel
	executeBtn.Text = "EXECUTE TURN"
	executeBtn.Parent = commandDeck
	addCorner(executeBtn, 8)
	self.ExecuteBtn = executeBtn

	-- Combat Log Action Banner
	local logBanner = Instance.new("TextLabel")
	logBanner.Name = "CombatLogBanner"
	logBanner.Size = UDim2.new(0, 560, 0, 60)
	logBanner.Position = UDim2.new(0.5, -280, 1, -200)
	logBanner.BackgroundColor3 = COLORS.PanelSoft
	logBanner.BackgroundTransparency = 0.25
	logBanner.Font = Enum.Font.GothamMedium
	logBanner.TextSize = 12
	logBanner.TextColor3 = COLORS.Text
	logBanner.TextWrapped = true
	logBanner.TextYAlignment = Enum.TextYAlignment.Bottom
	logBanner.Text = "Combat Initialized. Select ability and target."
	logBanner.Parent = container
	addCorner(logBanner, 6)
	self.LogBanner = logBanner

	executeBtn.MouseButton1Click:Connect(function()
		if self.Callbacks.OnSelectAction then
			self.Callbacks.OnSelectAction(
				self.SelectedAbilityType or "Basic",
				self.SelectedTargetId,
				self.CurrentTurnUnitId
			)
		end
	end)

	-- Terminal Control Panel (Overlay when at checkpoint)
	local terminalPanel = Instance.new("Frame")
	terminalPanel.Name = "TerminalPanel"
	terminalPanel.Size = UDim2.new(0, 440, 0, 240)
	terminalPanel.Position = UDim2.new(0.5, -220, 0.5, -120)
	terminalPanel.BackgroundColor3 = COLORS.Panel
	terminalPanel.Visible = false
	terminalPanel.Parent = container
	addCorner(terminalPanel, 14)
	addStroke(terminalPanel, COLORS.Cyan, 2)
	self.TerminalPanel = terminalPanel

	local termTitle = Instance.new("TextLabel")
	termTitle.Size = UDim2.new(1, 0, 0, 32)
	termTitle.Position = UDim2.new(0, 0, 0, 12)
	termTitle.BackgroundTransparency = 1
	termTitle.Font = Enum.Font.GothamBold
	termTitle.TextSize = 17
	termTitle.TextColor3 = COLORS.Cyan
	termTitle.Text = "STATION TERMINAL ONLINE"
	termTitle.Parent = terminalPanel

	local lootFrame = Instance.new("Frame")
	lootFrame.Name = "LootFrame"
	lootFrame.Size = UDim2.new(1, -40, 0, 54)
	lootFrame.Position = UDim2.new(0, 20, 0, 48)
	lootFrame.BackgroundColor3 = COLORS.PanelSoft
	lootFrame.Parent = terminalPanel
	addCorner(lootFrame, 8)

	local lootPending = Instance.new("TextLabel")
	lootPending.Name = "LootPending"
	lootPending.Size = UDim2.new(1, -20, 0, 24)
	lootPending.Position = UDim2.new(0, 10, 0, 4)
	lootPending.BackgroundTransparency = 1
	lootPending.Font = Enum.Font.GothamBold
	lootPending.TextSize = 12
	lootPending.TextColor3 = COLORS.Orange
	lootPending.TextXAlignment = Enum.TextXAlignment.Left
	lootPending.Text = "PENDING LOOT: +0 BioCoins, +0 DNA"
	lootPending.Parent = lootFrame
	self.LootPending = lootPending

	local lootSecured = Instance.new("TextLabel")
	lootSecured.Name = "LootSecured"
	lootSecured.Size = UDim2.new(1, -20, 0, 22)
	lootSecured.Position = UDim2.new(0, 10, 0, 26)
	lootSecured.BackgroundTransparency = 1
	lootSecured.Font = Enum.Font.GothamMedium
	lootSecured.TextSize = 11
	lootSecured.TextColor3 = COLORS.Lime
	lootSecured.TextXAlignment = Enum.TextXAlignment.Left
	lootSecured.Text = "SECURED LOOT: 0 BioCoins, 0 DNA"
	lootSecured.Parent = lootFrame
	self.LootSecured = lootSecured

	local secureBtn = Instance.new("TextButton")
	secureBtn.Size = UDim2.new(1, -40, 0, 36)
	secureBtn.Position = UDim2.new(0, 20, 0, 112)
	secureBtn.BackgroundColor3 = COLORS.Lime
	secureBtn.Font = Enum.Font.GothamBold
	secureBtn.TextSize = 13
	secureBtn.TextColor3 = COLORS.Panel
	secureBtn.Text = "SECURE CURRENT LOOT"
	secureBtn.Parent = terminalPanel
	addCorner(secureBtn, 8)
	secureBtn.MouseButton1Click:Connect(function()
		if self.Callbacks.OnSecureLoot then
			self.Callbacks.OnSecureLoot()
		end
	end)

	local evacBtn = Instance.new("TextButton")
	evacBtn.Size = UDim2.new(0.48, -15, 0, 36)
	evacBtn.Position = UDim2.new(0, 20, 0, 156)
	evacBtn.BackgroundColor3 = COLORS.Orange
	evacBtn.Font = Enum.Font.GothamBold
	evacBtn.TextSize = 13
	evacBtn.TextColor3 = COLORS.Panel
	evacBtn.Text = "EVACUATE (EXIT)"
	evacBtn.Parent = terminalPanel
	addCorner(evacBtn, 8)
	evacBtn.MouseButton1Click:Connect(function()
		if self.Callbacks.OnEvacuate then
			self.Callbacks.OnEvacuate()
		end
	end)

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.new(0.48, -15, 0, 36)
	nextBtn.Position = UDim2.new(0.52, 5, 0, 156)
	nextBtn.BackgroundColor3 = COLORS.Cyan
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.TextSize = 13
	nextBtn.TextColor3 = COLORS.Panel
	nextBtn.Text = "PROCEED NEXT ROOM"
	nextBtn.Parent = terminalPanel
	addCorner(nextBtn, 8)
	nextBtn.MouseButton1Click:Connect(function()
		if self.Callbacks.OnNextRoom then
			self.Callbacks.OnNextRoom()
		end
	end)

	return self
end

function CombatUI:SetVisible(visible)
	self.Container.Visible = visible
end

function CombatUI:UpdateCombat(combatState, expeditionSnapshot)
	local isAtTerminal = expeditionSnapshot ~= nil and expeditionSnapshot.Status == "AtTerminal"
	if not combatState and not isAtTerminal then
		self:SetVisible(false)
		return
	end

	self:SetVisible(true)

	-- Update Room Title & Progress
	if expeditionSnapshot then
		self.RoomTitle.Text = string.format(
			"ROOM %d/%d: %s [%s]",
			expeditionSnapshot.CurrentRoomIndex,
			expeditionSnapshot.TotalRooms,
			expeditionSnapshot.RoomTitle,
			expeditionSnapshot.Status
		)
		self.TerminalPanel.Visible = isAtTerminal
		if isAtTerminal and self.LootPending and self.LootSecured then
			local pending = expeditionSnapshot.PendingLoot or { BioCoins = 0, DnaFragments = 0 }
			local secured = expeditionSnapshot.SecuredLoot or { BioCoins = 0, DnaFragments = 0 }
			self.LootPending.Text = string.format(
				"PENDING LOOT: +%d BioCoins, +%d DNA",
				pending.BioCoins or 0,
				pending.DnaFragments or 0
			)
			self.LootSecured.Text = string.format(
				"SECURED LOOT: %d BioCoins, %d DNA",
				secured.BioCoins or 0,
				secured.DnaFragments or 0
			)
		end
	end

	self.CommandDeck.Visible = combatState ~= nil and not isAtTerminal
	self.TargetsFrame.Visible = combatState ~= nil and not isAtTerminal

	if not combatState then
		return
	end

	self.CurrentTurnUnitId = combatState.CurrentTurnUnitId

	-- Update recent combat log message
	if self.LogBanner and combatState and combatState.Log and #combatState.Log > 0 then
		local lines = {}
		local count = math.min(#combatState.Log, 4)
		for i = #combatState.Log - count + 1, #combatState.Log do
			local lg = combatState.Log[i]
			if lg and lg.Message then
				table.insert(lines, lg.Message)
			end
		end
		self.LogBanner.Text = table.concat(lines, "\n")

		local lastLog = combatState.Log[#combatState.Log]
		if lastLog and lastLog.Damage and lastLog.Damage > 0 then
			self.LogBanner.TextColor3 = Color3.fromRGB(255, 215, 80)
		else
			self.LogBanner.TextColor3 = COLORS.Cyan
		end
	end

	-- Update Timeline
	for _, child in self.Timeline:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, unitId in combatState.InitiativeQueue do
		local isPlayer = false
		local unitName = unitId:sub(1, 8)
		local unitHp = nil
		local unitMaxHp = nil

		for _, u in ipairs(combatState.PlayerTeam.Active) do
			if u.Id == unitId then
				isPlayer = true
				unitName = u.Name
				unitHp = u.CurrentHp
				unitMaxHp = u.MaxHp
				break
			end
		end

		if not isPlayer then
			for _, u in ipairs(combatState.EnemyTeam.Active) do
				if u.Id == unitId then
					isPlayer = false
					unitName = u.Name
					unitHp = u.CurrentHp
					unitMaxHp = u.MaxHp
					break
				end
			end
		end

		local isCurrent = unitId == combatState.CurrentTurnUnitId

		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 100, 0, 42)
		card.BackgroundColor3 = if isPlayer then COLORS.PanelSoft else Color3.fromRGB(45, 25, 28)
		card.Parent = self.Timeline
		addCorner(card, 6)

		if isCurrent then
			addStroke(card, COLORS.Cyan, 2)
		end

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 24)
		lbl.Position = UDim2.new(0, 0, 0, 2)
		lbl.BackgroundTransparency = 1
		lbl.Font = if isCurrent then Enum.Font.GothamBold else Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextColor3 = if isPlayer then COLORS.Lime else COLORS.Red
		lbl.Text = (if isPlayer then "[A] " else "[E] ") .. unitName
		lbl.Parent = card

		if unitHp and unitMaxHp then
			local hpBar = Instance.new("Frame")
			hpBar.Size = UDim2.new(1, -12, 0, 4)
			hpBar.Position = UDim2.new(0, 6, 1, -8)
			hpBar.BackgroundColor3 = COLORS.Panel
			hpBar.Parent = card
			addCorner(hpBar, 2)

			local fill = Instance.new("Frame")
			local pct = math.clamp(unitHp / math.max(1, unitMaxHp), 0, 1)
			fill.Size = UDim2.new(pct, 0, 1, 0)
			fill.BackgroundColor3 = if isPlayer then COLORS.Lime else COLORS.Red
			fill.Parent = hpBar
			addCorner(fill, 2)
		end
	end

	-- Update Energy Cells
	local playerEnergy = combatState.PlayerTeam.Energy
	local maxEnergy = combatState.PlayerTeam.MaxEnergy
	self.EnergyHeader.Text = string.format("TEAM ENERGY: %d / %d", playerEnergy, maxEnergy)

	for _, child in self.EnergyCells:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i = 1, maxEnergy do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0, 18, 0, 12)
		cell.BackgroundColor3 = if i <= playerEnergy then COLORS.Cyan else COLORS.Disabled
		cell.Parent = self.EnergyCells
		addCorner(cell, 3)
	end

	-- Update Abilities
	for _, child in self.AbilitiesContainer:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Find active player unit acting right now
	local activeUnit = nil
	for _, u in combatState.PlayerTeam.Active do
		if u.Id == combatState.CurrentTurnUnitId then
			activeUnit = u
			break
		end
	end

	local isPlayerTurn = activeUnit ~= nil

	-- Update Execute Button State
	if self.ExecuteBtn then
		if isPlayerTurn then
			self.ExecuteBtn.Active = true
			self.ExecuteBtn.AutoButtonColor = true
			self.ExecuteBtn.BackgroundColor3 = COLORS.Cyan
			self.ExecuteBtn.TextColor3 = COLORS.Panel
			self.ExecuteBtn.Text = "EXECUTE TURN"
		else
			self.ExecuteBtn.Active = false
			self.ExecuteBtn.AutoButtonColor = false
			self.ExecuteBtn.BackgroundColor3 = COLORS.Disabled
			self.ExecuteBtn.TextColor3 = COLORS.Muted
			self.ExecuteBtn.Text = "WAITING..."
		end
	end

	-- Ensure a valid living target is selected
	if not self.SelectedAbilityType then
		self.SelectedAbilityType = "Basic"
	end

	local isPlayerTurn = activeUnit ~= nil
	local selectedAbility: CombatTypes.Ability? = nil

	if activeUnit and isPlayerTurn then
		for _, ability in activeUnit.Abilities do
			if ability.Type == self.SelectedAbilityType then
				selectedAbility = ability
			end
			local canAfford = playerEnergy >= ability.EnergyCost
			local onCd = (activeUnit.Cooldowns[ability.Name] or 0) > 0

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 130, 0, 48)
			btn.BackgroundColor3 = if canAfford and not onCd then COLORS.Card else COLORS.Disabled
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 12
			btn.TextColor3 = COLORS.Text

			local isSelected = self.SelectedAbilityType == ability.Type
			if isSelected then
				addStroke(btn, COLORS.Lime, 2)
			end
			addCorner(btn, 8)

			local cdText = if onCd then string.format(" [CD:%d]", activeUnit.Cooldowns[ability.Name]) else ""
			btn.Text =
				string.format("%s\n[%s ⚡%d%s]", ability.Name, ability.Type, ability.EnergyCost, cdText)
			btn.Parent = self.AbilitiesContainer

			btn.MouseButton1Click:Connect(function()
				if canAfford and not onCd then
					self.SelectedAbilityType = ability.Type
					self:UpdateCombat(combatState, expeditionSnapshot)
				end
			end)
		end
	end

	local isAllyTarget = selectedAbility ~= nil and selectedAbility.TargetType == "SingleAlly"
	local candidateTargets = if isAllyTarget
		then combatState.PlayerTeam.Active
		else combatState.EnemyTeam.Active

	local targetStillAlive = false
	for _, unit in candidateTargets do
		if unit.IsAlive and unit.CurrentHp > 0 and unit.Id == self.SelectedTargetId then
			targetStillAlive = true
			break
		end
	end
	if not targetStillAlive then
		self.SelectedTargetId = nil
		for _, unit in candidateTargets do
			if unit.IsAlive and unit.CurrentHp > 0 then
				self.SelectedTargetId = unit.Id
				break
			end
		end
	end

	if self.Callbacks and self.Callbacks.OnTargetSelected and self.SelectedTargetId then
		self.Callbacks.OnTargetSelected(self.SelectedTargetId)
	end

	-- Update Targets
	for _, child in self.TargetsFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, targetUnit in candidateTargets do
		if targetUnit.IsAlive and targetUnit.CurrentHp > 0 then
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0, 140, 0, 88)
			card.BackgroundColor3 = COLORS.Card
			card.Parent = self.TargetsFrame
			addCorner(card, 8)

			if self.SelectedTargetId == targetUnit.Id then
				addStroke(card, if isAllyTarget then COLORS.Lime else COLORS.Cyan, 2)
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, 0, 0, 20)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextSize = 12
			nameLbl.TextColor3 = if isAllyTarget then COLORS.Lime else COLORS.Red
			nameLbl.Text = targetUnit.Name
			nameLbl.Parent = card

			local hpLbl = Instance.new("TextLabel")
			hpLbl.Size = UDim2.new(1, 0, 0, 16)
			hpLbl.Position = UDim2.new(0, 0, 0, 20)
			hpLbl.BackgroundTransparency = 1
			hpLbl.Font = Enum.Font.Gotham
			hpLbl.TextSize = 10
			hpLbl.TextColor3 = COLORS.Muted
			hpLbl.Text = string.format("HP: %d/%d", targetUnit.CurrentHp, targetUnit.MaxHp)
			hpLbl.Parent = card

			local hpBg = Instance.new("Frame")
			hpBg.Size = UDim2.new(1, -20, 0, 5)
			hpBg.Position = UDim2.new(0, 10, 0, 38)
			hpBg.BackgroundColor3 = COLORS.PanelSoft
			hpBg.Parent = card
			addCorner(hpBg, 2)

			local hpPct = math.clamp(targetUnit.CurrentHp / math.max(1, targetUnit.MaxHp), 0, 1)
			local hpFill = Instance.new("Frame")
			hpFill.Size = UDim2.new(hpPct, 0, 1, 0)
			hpFill.BackgroundColor3 = if hpPct > 0.5
				then COLORS.Lime
				elseif hpPct > 0.25 then COLORS.Orange
				else COLORS.Red
			hpFill.Parent = hpBg
			addCorner(hpFill, 2)

			-- Calculate Matchup indicator or Heal indicator if an active player unit is ready
			if activeUnit then
				local multLbl = Instance.new("TextLabel")
				multLbl.Size = UDim2.new(1, 0, 0, 18)
				multLbl.Position = UDim2.new(0, 0, 0, 48)
				multLbl.BackgroundTransparency = 1
				multLbl.Font = Enum.Font.GothamBold
				multLbl.TextSize = 11

				if isAllyTarget then
					multLbl.TextColor3 = COLORS.Lime
					multLbl.Text = "💚 ALLY HEAL"
				else
					local attackElem = (selectedAbility and selectedAbility.Element)
						or activeUnit.Stats.EffectiveElements.Primary
					local mult = ElementMatrix.GetCompositeMultiplier(
						attackElem,
						targetUnit.Stats.EffectiveElements,
						activeUnit.HasVoidCore,
						targetUnit.HasVoidCore
					)

					if mult > 1.0 then
						multLbl.TextColor3 = COLORS.Red
						multLbl.Text = string.format("⚔ %.1fx WEAK", mult)
					elseif mult < 1.0 then
						multLbl.TextColor3 = COLORS.Cyan
						multLbl.Text = string.format("🛡 %.2fx RESIST", mult)
					else
						multLbl.TextColor3 = COLORS.Muted
						multLbl.Text = "⚖ 1.0x NEUTRAL"
					end
				end
				multLbl.Parent = card
			end

			local selectBtn = Instance.new("TextButton")
			selectBtn.Size = UDim2.new(1, 0, 1, 0)
			selectBtn.BackgroundTransparency = 1
			selectBtn.Text = ""
			selectBtn.Parent = card
			selectBtn.MouseButton1Click:Connect(function()
				self.SelectedTargetId = targetUnit.Id
				self:UpdateCombat(combatState, expeditionSnapshot)
			end)
		end
	end
end

function CombatUI:Destroy()
	if self.Container then
		self.Container:Destroy()
	end
end

return CombatUI
