--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatUI = require(script.Parent.CombatUI)
local SquadUI = require(script.Parent.SquadUI)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local isRoblox = typeof(script) == "Instance" and typeof(game) == "Instance"
local rootStorage = if isRoblox then ReplicatedStorage:WaitForChild("MutantLab") else nil
local sharedStorage = if rootStorage then rootStorage:WaitForChild("Shared") else nil
local MutantStats = if isRoblox
	then require(sharedStorage:WaitForChild("Combat"):WaitForChild("MutantStats"))
	else require("../../shared/Combat/MutantStats")

local UIController = {}
UIController.__index = UIController

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
	Disabled = Color3.fromRGB(69, 78, 84),
}

local SOUNDS = {
	Click = "rbxasset://sounds/button.wav",
	Create = "rbxasset://sounds/electronicpingshort.wav",
	Merge = "rbxasset://sounds/action_jump.mp3",
	Battle = "rbxasset://sounds/impact_water.mp3",
	Victory = "rbxasset://sounds/victory.wav",
	Error = "rbxasset://sounds/bass.wav",
	Hit = "rbxasset://sounds/action_falling_feather.mp3",
	Crit = "rbxasset://sounds/snap.wav",
	Heal = "rbxasset://sounds/electronicpingshort.wav",
}

local ERROR_TEXT = {
	NOT_READY = "The lab is still loading. Try again in a moment.",
	RATE_LIMITED = "Too many experiments at once. Slow down.",
	INVALID_REQUEST = "That request was not understood.",
	INSUFFICIENT_FUNDS = "You need more BioCoins.",
	INVENTORY_FULL = "Your mutant slots are full.",
	INVALID_MERGE = "Select two identical mutants to merge (2x Blob or 2x Toxic Blob).",
	MUTANT_NOT_FOUND = "That mutant is no longer available.",
	MUTANT_BUSY = "That mutant is assigned to an active battle or expedition.",
	BATTLE_RUNNING = "A training battle is already running.",
	TUTORIAL_REQUIRED = "Follow the current tutorial step first.",
	LAST_MUTANT = "You cannot release your last mutant.",
	INTERNAL_ERROR = "The lab hit an internal error. Please retry.",
	CONNECTION_ERROR = "Connection lost. Please retry.",
	INVALID_BREED_TARGETS = "Select two different specimens to breed.",
	MUTANT_RESTING = "One of the selected specimens is currently resting.",
	BREEDING_FAILED = "Genetic synthesis failed to stabilize.",
	EXPEDITION_ACTIVE = "An expedition is already in progress.",
	INVALID_SQUAD = "Select distinct, ready mutants for your squad.",
	CANNOT_PROCEED = "Finish the current battle before continuing.",
	CANNOT_EVACUATE = "Evacuation is only available at an active terminal.",
	NOT_AT_TERMINAL = "Reach a terminal to secure loot.",
	GENE_LIMIT_REACHED = "This synthesis would exceed the gene limit.",
}

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, size, color, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = font or Enum.Font.Gotham
	label.TextSize = 15
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.Size = UDim2.new(1, 0, 0, 48)
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = parent
	addCorner(button, 10)
	return button
end

local function setEnabled(button, enabled, activeColor)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then activeColor else COLORS.Disabled
	button.TextTransparency = if enabled then 0 else 0.35
end

function UIController.new(callbacks, gameConfig)
	local self = setmetatable({}, UIController)
	self._callbacks = callbacks
	self._gameConfig = gameConfig
	self._state = nil
	self._busy = false
	self._selected = {}
	self._connections = {}
	self._toastGeneration = 0
	self._minimized = false
	self:_build()
	return self
end

function UIController:_playSound(soundName)
	local soundId = SOUNDS[soundName]
	if not soundId then
		return
	end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = game:GetService("SoundService")
		sound.PlayOnRemove = true
		sound:Destroy()
	end)
end

function UIController:_build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "MutantLabUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 20
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._screen = screen

	local panel = Instance.new("Frame")
	panel.Name = "ControlPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 10)
	panel.Size = UDim2.fromOffset(390, 620)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.04
	panel.ClipsDescendants = true
	panel.Parent = screen
	addCorner(panel, 16)
	addStroke(panel, COLORS.Cyan, 1, 0.65)
	self._panel = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(18, 12)
	header.Size = UDim2.new(1, -36, 0, 58)
	header.Parent = panel

	local title =
		makeLabel(header, "MUTANT LAB", UDim2.new(0.52, 0, 0, 28), COLORS.Text, Enum.Font.GothamBlack)
	title.TextSize = 20
	local subtitle = makeLabel(
		header,
		"BIO RESEARCH TERMINAL",
		UDim2.new(0.52, 0, 0, 20),
		COLORS.Muted,
		Enum.Font.GothamMedium
	)
	subtitle.Position = UDim2.fromOffset(0, 29)
	subtitle.TextSize = 10
	subtitle.TextTransparency = 0.1

	local balance = makeLabel(header, "◉  --", UDim2.new(0.32, 0, 0, 36), COLORS.Lime, Enum.Font.GothamBold)
	balance.Position = UDim2.new(0.52, 0, 0, 4)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	balance.TextSize = 17
	self._balance = balance

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleMinimize"
	toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
	toggleBtn.Position = UDim2.new(1, 0, 0.5, 0)
	toggleBtn.Size = UDim2.fromOffset(34, 34)
	toggleBtn.BackgroundColor3 = COLORS.PanelSoft
	toggleBtn.Text = "▲"
	toggleBtn.TextColor3 = COLORS.Cyan
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 14
	toggleBtn.Parent = header
	addCorner(toggleBtn, 8)
	addStroke(toggleBtn, COLORS.Cyan, 1, 0.5)
	self._toggleBtn = toggleBtn

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(14, 76)
	scroll.Size = UDim2.new(1, -28, 1, -88)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = COLORS.Cyan
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = panel
	self._scroll = scroll

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local status = makeLabel(
		scroll,
		"Connecting to the lab...",
		UDim2.new(1, 0, 0, 42),
		COLORS.Orange,
		Enum.Font.GothamMedium
	)
	status.Name = "Status"
	status.LayoutOrder = 1
	status.BackgroundTransparency = 0.05
	status.BackgroundColor3 = COLORS.PanelSoft
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextSize = 13
	addCorner(status, 9)
	self._status = status

	local retry = makeButton(scroll, "RETRY CONNECTION", COLORS.Orange)
	retry.Name = "Retry"
	retry.LayoutOrder = 2
	retry.Visible = false
	retry.Activated:Connect(function()
		self._callbacks.OnRetry()
	end)
	self._retry = retry

	local hint = makeLabel(scroll, "", UDim2.new(1, 0, 0, 58), COLORS.Cyan, Enum.Font.GothamMedium)
	hint.Name = "TutorialHint"
	hint.LayoutOrder = 3
	hint.BackgroundColor3 = Color3.fromRGB(22, 52, 57)
	hint.BackgroundTransparency = 0.1
	hint.TextWrapped = true
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Center
	addCorner(hint, 10)
	addStroke(hint, COLORS.Cyan, 1, 0.6)
	self._hint = hint

	local inventoryTitle = makeLabel(
		scroll,
		"SPECIMENS  •  SELECT UP TO 2",
		UDim2.new(1, 0, 0, 24),
		COLORS.Muted,
		Enum.Font.GothamBold
	)
	inventoryTitle.LayoutOrder = 4
	inventoryTitle.TextSize = 11
	self._inventoryTitle = inventoryTitle

	local inventory = Instance.new("Frame")
	inventory.Name = "Inventory"
	inventory.LayoutOrder = 5
	inventory.BackgroundTransparency = 1
	inventory.Size = UDim2.new(1, 0, 0, 0)
	inventory.AutomaticSize = Enum.AutomaticSize.Y
	inventory.Parent = scroll
	local inventoryList = Instance.new("UIListLayout")
	inventoryList.Padding = UDim.new(0, 7)
	inventoryList.SortOrder = Enum.SortOrder.LayoutOrder
	inventoryList.Parent = inventory
	self._inventory = inventory

	local actionsTitle =
		makeLabel(scroll, "EXPERIMENTS", UDim2.new(1, 0, 0, 24), COLORS.Muted, Enum.Font.GothamBold)
	actionsTitle.LayoutOrder = 6
	actionsTitle.TextSize = 11

	local create = makeButton(scroll, "CREATE BLOB", COLORS.Cyan)
	create.LayoutOrder = 7
	create.Activated:Connect(function()
		if not self._busy and self._state then
			self:_playSound("Click")
			self._callbacks.OnAction("CreateBlob", nil)
		end
	end)
	self._create = create

	local merge = makeButton(scroll, "MERGE SELECTED", COLORS.Purple)
	merge.LayoutOrder = 8
	merge.Activated:Connect(function()
		if not self._busy and #self._selected == 2 then
			self:_playSound("Click")
			self._callbacks.OnAction("Merge", { FirstId = self._selected[1], SecondId = self._selected[2] })
		end
	end)
	self._merge = merge

	local breedBtn = makeButton(scroll, "BREED SELECTED (DNA)", COLORS.Lime)
	breedBtn.LayoutOrder = 9
	breedBtn.Activated:Connect(function()
		if not self._busy and #self._selected == 2 then
			self:_playSound("Click")
			self._callbacks.OnAction(
				"BreedMutants",
				{ FirstId = self._selected[1], SecondId = self._selected[2] }
			)
		end
	end)
	self._breedBtn = breedBtn

	local battle = makeButton(scroll, "START TRAINING", COLORS.Orange)
	battle.LayoutOrder = 10
	battle.Activated:Connect(function()
		if not self._busy and #self._selected == 1 then
			self:_playSound("Click")
			self._callbacks.OnAction("StartBattle", { MutantId = self._selected[1] })
		end
	end)
	self._battleButton = battle

	local expeditionBtn = makeButton(scroll, "EXPEDITIONS (3v3)", COLORS.Cyan)
	expeditionBtn.LayoutOrder = 11
	expeditionBtn.Activated:Connect(function()
		self:_playSound("Click")
		if self._squadUI then
			self._squadUI:SetVisible(true)
		end
	end)
	self._expeditionBtn = expeditionBtn

	local squadUI = SquadUI.new(screen, {
		OnDeploy = function(payload)
			self:_playSound("Click")
			self._callbacks.OnAction("StartExpedition", payload)
		end,
	})
	self._squadUI = squadUI

	local combatUI = CombatUI.new(screen, {
		OnSelectAction = function(abilityType, targetId, actorId)
			self:_playSound("Click")
			self._callbacks.OnAction("SelectCombatAction", {
				AbilityType = abilityType,
				TargetId = targetId,
				ActorId = actorId,
			})
		end,
		OnSecureLoot = function()
			self:_playSound("Click")
			self._callbacks.OnAction("SecureLoot", nil)
		end,
		OnEvacuate = function()
			self:_playSound("Click")
			self._callbacks.OnAction("Evacuate", nil)
		end,
		OnNextRoom = function()
			self:_playSound("Click")
			self._callbacks.OnAction("ProceedNextRoom", nil)
		end,
		OnTargetSelected = function(targetId)
			if self._callbacks and self._callbacks.OnCombatTargetSelected then
				self._callbacks.OnCombatTargetSelected(targetId)
			end
		end,
		OnResetCamera = function()
			if self._callbacks and self._callbacks.OnResetCombatCamera then
				self._callbacks.OnResetCombatCamera()
			end
		end,
	})
	self._combatUI = combatUI

	local battleStatus = makeLabel(
		scroll,
		"No active training battle",
		UDim2.new(1, 0, 0, 42),
		COLORS.Muted,
		Enum.Font.GothamMedium
	)
	battleStatus.LayoutOrder = 11
	battleStatus.BackgroundColor3 = COLORS.PanelSoft
	battleStatus.BackgroundTransparency = 0.1
	battleStatus.TextXAlignment = Enum.TextXAlignment.Center
	battleStatus.TextSize = 13
	addCorner(battleStatus, 9)
	self._battleStatus = battleStatus

	local mode = makeLabel(scroll, "Persistence: --", UDim2.new(1, 0, 0, 22), COLORS.Muted, Enum.Font.Gotham)
	mode.LayoutOrder = 12
	mode.TextSize = 10
	mode.TextXAlignment = Enum.TextXAlignment.Center
	self._mode = mode

	local toast = makeLabel(screen, "", UDim2.fromOffset(330, 48), COLORS.Text, Enum.Font.GothamBold)
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 16)
	toast.BackgroundColor3 = COLORS.Panel
	toast.BackgroundTransparency = 0.05
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 40
	addCorner(toast, 12)
	addStroke(toast, COLORS.Cyan, 1, 0.4)
	self._toast = toast

	self:_buildConfirm()

	local function resize()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local isLandscape = viewport.X >= viewport.Y

		if not isLandscape and viewport.X < 600 then
			panel.AnchorPoint = Vector2.new(1, 1)
			panel.Position = UDim2.new(1, -10, 1, -10)
			panel.Size = if self._minimized then UDim2.new(1, -20, 0, 78) else UDim2.new(1, -20, 0.58, 0)
		elseif isLandscape and viewport.Y < 480 then
			local width = math.floor(math.clamp(viewport.X * 0.45, 270, 340))
			panel.AnchorPoint = Vector2.new(1, 0)
			panel.Position = UDim2.new(1, -10, 0, 10)
			panel.Size = if self._minimized then UDim2.new(0, width, 0, 78) else UDim2.new(0, width, 1, -20)
		else
			local width = if viewport.X < 700
				then math.floor(math.clamp(viewport.X * 0.65, 300, 350))
				else math.floor(math.clamp(viewport.X * 0.34, 350, 420))
			panel.AnchorPoint = Vector2.new(1, 0)
			panel.Position = UDim2.new(1, -10, 0, 10)
			panel.Size = if self._minimized then UDim2.new(0, width, 0, 78) else UDim2.new(0, width, 1, -20)
		end
	end
	resize()

	self._toggleBtn.Activated:Connect(function()
		self._minimized = not self._minimized
		self._scroll.Visible = not self._minimized
		self._toggleBtn.Text = if self._minimized then "▼" else "▲"
		self:_playSound("Click")
		resize()
	end)
	if workspace.CurrentCamera then
		table.insert(
			self._connections,
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		)
	end
	table.insert(self._connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resize))
	table.insert(
		self._connections,
		RunService.RenderStepped:Connect(function()
			self:_updateBattleClock()
		end)
	)

	self:_buildConfirm()
	self:_buildStatsModal()
	self:_refreshControls()
end

function UIController:_buildConfirm()
	local shade = Instance.new("Frame")
	shade.Name = "ReleaseConfirmation"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.25
	shade.Visible = false
	shade.ZIndex = 50
	shade.Parent = self._screen
	self._confirmShade = shade

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(0.86, 0, 0, 210)
	local boxConstraint = Instance.new("UISizeConstraint")
	boxConstraint.MinSize = Vector2.new(260, 210)
	boxConstraint.MaxSize = Vector2.new(330, 210)
	boxConstraint.Parent = box
	box.BackgroundColor3 = COLORS.Panel
	box.ZIndex = 51
	box.Parent = shade
	addCorner(box, 16)
	addStroke(box, COLORS.Red, 2, 0.2)

	local title =
		makeLabel(box, "RELEASE SPECIMEN?", UDim2.new(1, -32, 0, 34), COLORS.Red, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 16)
	title.TextSize = 18
	title.ZIndex = 52
	local message = makeLabel(
		box,
		"This permanently frees the slot. You receive no refund.",
		UDim2.new(1, -32, 0, 64),
		COLORS.Text,
		Enum.Font.Gotham
	)
	message.Position = UDim2.fromOffset(16, 55)
	message.TextWrapped = true
	message.TextSize = 14
	message.ZIndex = 52

	local cancel = makeButton(box, "CANCEL", COLORS.Disabled)
	cancel.Position = UDim2.new(0, 16, 1, -64)
	cancel.Size = UDim2.new(0.46, -8, 0, 48)
	cancel.ZIndex = 52
	cancel.Activated:Connect(function()
		shade.Visible = false
		self._releaseId = nil
	end)
	local release = makeButton(box, "RELEASE", COLORS.Red)
	release.Position = UDim2.new(0.54, 0, 1, -64)
	release.Size = UDim2.new(0.46, -16, 0, 48)
	release.ZIndex = 52
	release.Activated:Connect(function()
		local mutantId = self._releaseId
		shade.Visible = false
		self._releaseId = nil
		if mutantId and not self._busy then
			self._callbacks.OnAction("ReleaseMutant", { MutantId = mutantId })
		end
	end)
end

function UIController:_showRelease(mutantId)
	self._releaseId = mutantId
	self._confirmShade.Visible = true
end

function UIController:_buildStatsModal()
	local shade = Instance.new("Frame")
	shade.Name = "StatsModalShade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.Visible = false
	shade.ZIndex = 60
	shade.Parent = self._screen
	self._statsShade = shade

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.new(0, 460, 0, 500)
	box.BackgroundColor3 = COLORS.Panel
	box.ZIndex = 61
	box.Parent = shade
	addCorner(box, 14)
	addStroke(box, COLORS.Cyan, 2, 0.15)

	local title =
		makeLabel(box, "SPECIMEN ANALYSIS", UDim2.new(1, -60, 0, 32), COLORS.Cyan, Enum.Font.GothamBlack)
	title.Position = UDim2.fromOffset(16, 12)
	title.TextSize = 17
	title.ZIndex = 62

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = COLORS.PanelSoft
	closeBtn.Text = "×"
	closeBtn.TextColor3 = COLORS.Text
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 22
	closeBtn.ZIndex = 62
	closeBtn.Parent = box
	addCorner(closeBtn, 6)
	closeBtn.Activated:Connect(function()
		self:_playSound("Click")
		shade.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "StatsScroll"
	scroll.Size = UDim2.new(1, -32, 1, -95)
	scroll.Position = UDim2.fromOffset(16, 48)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = COLORS.Cyan
	scroll.ZIndex = 62
	scroll.Parent = box
	self._statsScroll = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local bottomClose = makeButton(box, "CLOSE ANALYSIS", COLORS.PanelSoft)
	bottomClose.Size = UDim2.new(1, -32, 0, 36)
	bottomClose.Position = UDim2.new(0, 16, 1, -44)
	bottomClose.ZIndex = 62
	bottomClose.Activated:Connect(function()
		self:_playSound("Click")
		shade.Visible = false
	end)
end

function UIController:_showStats(mutant)
	if not self._statsShade or not self._statsScroll then
		return
	end
	self:_playSound("Click")
	self._statsScroll:ClearAllChildren()

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = self._statsScroll

	local genes = mutant.Genes or {}
	local role = mutant.Role or "Striker"
	local tier = mutant.Tier or 1
	local calculated = MutantStats.CalculateStats(tier, genes, role)
	local effective = calculated.EffectiveElements

	local displayName = if mutant.Type == "PlasmaBlob"
		then "PLASMA BLOB"
		elseif mutant.Type == "ToxicBlob" then "TOXIC BLOB"
		else "BLOB"
	local nameColor = if mutant.Type == "PlasmaBlob"
		then COLORS.Purple
		elseif mutant.Type == "ToxicBlob" then COLORS.Lime
		else COLORS.Cyan

	-- 1. Identity & Role Card
	local idCard = Instance.new("Frame")
	idCard.Size = UDim2.new(1, 0, 0, 78)
	idCard.BackgroundColor3 = COLORS.Card
	idCard.LayoutOrder = 1
	idCard.ZIndex = 63
	idCard.Parent = self._statsScroll
	addCorner(idCard, 8)

	local nameLbl = makeLabel(idCard, displayName, UDim2.new(0.6, 0, 0, 26), nameColor, Enum.Font.GothamBlack)
	nameLbl.Position = UDim2.fromOffset(12, 8)
	nameLbl.TextSize = 16
	nameLbl.ZIndex = 64

	local tierLbl = makeLabel(
		idCard,
		string.format("TIER %d • LEVEL %d", tier, mutant.Level or 1),
		UDim2.new(0.6, 0, 0, 18),
		COLORS.Muted,
		Enum.Font.GothamBold
	)
	tierLbl.Position = UDim2.fromOffset(12, 34)
	tierLbl.TextSize = 11
	tierLbl.ZIndex = 64

	local roleBadge = makeLabel(
		idCard,
		"ROLE: " .. string.upper(role),
		UDim2.new(0.35, 0, 0, 24),
		COLORS.Lime,
		Enum.Font.GothamBold
	)
	roleBadge.Position = UDim2.new(0.62, 0, 0, 8)
	roleBadge.BackgroundColor3 = COLORS.PanelSoft
	roleBadge.BackgroundTransparency = 0.2
	roleBadge.TextSize = 11
	roleBadge.ZIndex = 64
	addCorner(roleBadge, 4)

	local roleDescText = if role == "Guardian"
		then "Frontline tank (+25% Max HP, taunt ability)."
		elseif role == "Healer" then "Restoration support (team HP recovery)."
		elseif role == "Buffer" then "Tactical booster (attack & energy surging)."
		elseif role == "Controller" then "Battlefield disruptor (slows & disables)."
		else "High single-target burst damage dealer."
	local roleDesc = makeLabel(idCard, roleDescText, UDim2.new(1, -24, 0, 18), COLORS.Text, Enum.Font.Gotham)
	roleDesc.Position = UDim2.fromOffset(12, 54)
	roleDesc.TextSize = 10
	roleDesc.ZIndex = 64

	-- 2. Combat Attributes (4-grid)
	local statsCard = Instance.new("Frame")
	statsCard.Size = UDim2.new(1, 0, 0, 68)
	statsCard.BackgroundColor3 = COLORS.Card
	statsCard.LayoutOrder = 2
	statsCard.ZIndex = 63
	statsCard.Parent = self._statsScroll
	addCorner(statsCard, 8)

	local statItems = {
		{ Label = "HEALTH", Value = tostring(calculated.MaxHp), Icon = "❤️", Color = COLORS.Red },
		{ Label = "ATTACK", Value = tostring(calculated.Attack), Icon = "⚔️", Color = COLORS.Orange },
		{ Label = "DEFENSE", Value = "0", Icon = "🛡️", Color = COLORS.Cyan },
		{ Label = "SPEED", Value = tostring(calculated.Speed), Icon = "⚡", Color = COLORS.Lime },
	}

	for i, item in ipairs(statItems) do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0.25, -6, 1, -12)
		cell.Position = UDim2.new((i - 1) * 0.25, 3, 0, 6)
		cell.BackgroundColor3 = COLORS.PanelSoft
		cell.ZIndex = 64
		cell.Parent = statsCard
		addCorner(cell, 6)

		local valLbl = makeLabel(
			cell,
			item.Icon .. " " .. item.Value,
			UDim2.new(1, 0, 0, 24),
			item.Color,
			Enum.Font.GothamBlack
		)
		valLbl.Position = UDim2.fromOffset(0, 6)
		valLbl.TextSize = 12
		valLbl.TextXAlignment = Enum.TextXAlignment.Center
		valLbl.ZIndex = 65

		local subLbl = makeLabel(cell, item.Label, UDim2.new(1, 0, 0, 16), COLORS.Muted, Enum.Font.GothamBold)
		subLbl.Position = UDim2.fromOffset(0, 30)
		subLbl.TextSize = 9
		subLbl.TextXAlignment = Enum.TextXAlignment.Center
		subLbl.ZIndex = 65
	end

	-- 3. Genetic Structure & Elements
	local maxSlots = if tier == 1 then 3 else (if tier == 2 then 4 else 5)
	local geneCardHeight = 56 + math.max(1, #genes) * 22
	local geneCard = Instance.new("Frame")
	geneCard.Size = UDim2.new(1, 0, 0, geneCardHeight)
	geneCard.BackgroundColor3 = COLORS.Card
	geneCard.LayoutOrder = 3
	geneCard.ZIndex = 63
	geneCard.Parent = self._statsScroll
	addCorner(geneCard, 8)

	local geneTitle = makeLabel(
		geneCard,
		string.format("🧬 GENETICS (%d/%d SLOTS)", #genes, maxSlots),
		UDim2.new(1, -24, 0, 22),
		COLORS.Cyan,
		Enum.Font.GothamBold
	)
	geneTitle.Position = UDim2.fromOffset(12, 6)
	geneTitle.TextSize = 11
	geneTitle.ZIndex = 64

	local elemTag = makeLabel(
		geneCard,
		string.format(
			"PRIMARY: %s • SECONDARY: %s",
			effective.Primary or "Biomass",
			effective.Secondary or "None"
		),
		UDim2.new(1, -24, 0, 18),
		COLORS.Lime,
		Enum.Font.GothamBold
	)
	elemTag.Position = UDim2.fromOffset(12, 28)
	elemTag.TextSize = 10
	elemTag.ZIndex = 64

	if #genes == 0 then
		local noGenes = makeLabel(
			geneCard,
			"No mutant genes inherited yet. Synthesize in Breeding Station.",
			UDim2.new(1, -24, 0, 20),
			COLORS.Muted,
			Enum.Font.Gotham
		)
		noGenes.Position = UDim2.fromOffset(12, 50)
		noGenes.TextSize = 10
		noGenes.ZIndex = 64
	else
		for gIdx, g in ipairs(genes) do
			local gLbl = makeLabel(
				geneCard,
				string.format("• %s Gene: +%d points", g.Element, g.Value),
				UDim2.new(1, -24, 0, 18),
				COLORS.Text,
				Enum.Font.GothamMedium
			)
			gLbl.Position = UDim2.fromOffset(16, 48 + (gIdx - 1) * 22)
			gLbl.TextSize = 11
			gLbl.ZIndex = 64
		end
	end

	-- 4. Combat Abilities
	local abilities = MutantStats.BuildAbilities(tier, role, calculated)
	local abilityCard = Instance.new("Frame")
	abilityCard.Size = UDim2.new(1, 0, 0, 36 + #abilities * 44)
	abilityCard.BackgroundColor3 = COLORS.Card
	abilityCard.LayoutOrder = 4
	abilityCard.ZIndex = 63
	abilityCard.Parent = self._statsScroll
	addCorner(abilityCard, 8)

	local abTitle = makeLabel(
		abilityCard,
		"⚔️ COMBAT SKILLS",
		UDim2.new(1, -24, 0, 22),
		COLORS.Cyan,
		Enum.Font.GothamBold
	)
	abTitle.Position = UDim2.fromOffset(12, 6)
	abTitle.TextSize = 11
	abTitle.ZIndex = 64

	for abIdx, ab in ipairs(abilities) do
		local costText = if ab.EnergyCost == 0
			then "0 ⚡ (+1 Gain)"
			else string.format("%d ⚡", ab.EnergyCost)
		local cdText = if ab.Cooldown > 0 then string.format(" [CD: %d turns]", ab.Cooldown) else ""
		local abRow = makeLabel(
			abilityCard,
			string.format("[%s] %s  •  Cost: %s%s", ab.Type, ab.Name, costText, cdText),
			UDim2.new(1, -24, 0, 20),
			COLORS.Orange,
			Enum.Font.GothamBold
		)
		abRow.Position = UDim2.fromOffset(12, 30 + (abIdx - 1) * 44)
		abRow.TextSize = 11
		abRow.ZIndex = 64

		local abDesc = makeLabel(
			abilityCard,
			ab.Description or "Deals element-aligned damage to target.",
			UDim2.new(1, -24, 0, 18),
			COLORS.Muted,
			Enum.Font.Gotham
		)
		abDesc.Position = UDim2.fromOffset(12, 48 + (abIdx - 1) * 44)
		abDesc.TextSize = 10
		abDesc.ZIndex = 64
	end

	-- 5. Rest Status
	local now = os.time()
	local isResting = mutant.RestUntil and mutant.RestUntil > now
	local statusCard = Instance.new("Frame")
	statusCard.Size = UDim2.new(1, 0, 0, 50)
	statusCard.BackgroundColor3 = if isResting then Color3.fromRGB(45, 30, 20) else Color3.fromRGB(20, 40, 30)
	statusCard.LayoutOrder = 5
	statusCard.ZIndex = 63
	statusCard.Parent = self._statsScroll
	addCorner(statusCard, 8)

	local statusText = if isResting
		then string.format(
			"⏳ RESTING: %d seconds remaining. 40%% mutation bonus upon rest completion.",
			mutant.RestUntil - now
		)
		else "✅ READY FOR ACTION: Available for expeditions and genetic synthesis."
	local statusLbl = makeLabel(
		statusCard,
		statusText,
		UDim2.new(1, -24, 1, 0),
		if isResting then COLORS.Orange else COLORS.Lime,
		Enum.Font.GothamBold
	)
	statusLbl.Position = UDim2.fromOffset(12, 0)
	statusLbl.TextWrapped = true
	statusLbl.TextSize = 11
	statusLbl.ZIndex = 64

	self._statsScroll.CanvasSize = UDim2.new(0, 0, 0, 310 + geneCardHeight + #abilities * 44)
	self._statsShade.Visible = true
end

function UIController:_isSelected(mutantId)
	return table.find(self._selected, mutantId) ~= nil
end

function UIController:_toggleSelected(mutantId)
	local index = table.find(self._selected, mutantId)
	if index then
		table.remove(self._selected, index)
		self:_playSound("Click")
	elseif #self._selected < 2 then
		table.insert(self._selected, mutantId)
		self:_playSound("Click")
	else
		self:ShowToast("You can select at most two specimens.", COLORS.Orange)
		self:_playSound("Error")
	end
	self:_renderInventory()
	self:_refreshControls()
	if self._callbacks.OnSelectionChanged then
		self._callbacks.OnSelectionChanged(self._selected)
	end
end

function UIController:_renderInventory()
	self._inventory:ClearAllChildren()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 7)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = self._inventory

	if not self._state or #(self._state.Mutants or {}) == 0 then
		local empty = makeLabel(
			self._inventory,
			"No specimens yet. Create your first Blob.",
			UDim2.new(1, 0, 0, 54),
			COLORS.Muted,
			Enum.Font.Gotham
		)
		empty.BackgroundColor3 = COLORS.PanelSoft
		empty.BackgroundTransparency = 0.15
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.TextWrapped = true
		addCorner(empty, 10)
		return
	end

	for order, mutant in self._state.Mutants do
		local selected = self:_isSelected(mutant.Id)
		local card = Instance.new("Frame")
		card.Name = tostring(mutant.Id)
		card.LayoutOrder = order
		card.Size = UDim2.new(1, 0, 0, 88)
		card.BackgroundColor3 = if selected then Color3.fromRGB(40, 78, 75) else COLORS.Card
		card.Parent = self._inventory
		addCorner(card, 10)
		addStroke(
			card,
			if selected then COLORS.Cyan else COLORS.PanelSoft,
			if selected then 2 else 1,
			if selected then 0.1 else 0.7
		)

		local selectButton = Instance.new("TextButton")
		selectButton.BackgroundTransparency = 1
		selectButton.Size = UDim2.new(1, -94, 1, 0)
		selectButton.Text = ""
		selectButton.Parent = card
		local displayName = if mutant.Type == "PlasmaBlob"
			then "PLASMA BLOB"
			elseif mutant.Type == "ToxicBlob" then "TOXIC BLOB"
			else "BLOB"
		local nameColor = if mutant.Type == "PlasmaBlob"
			then COLORS.Purple
			elseif mutant.Type == "ToxicBlob" then COLORS.Lime
			else COLORS.Cyan
		local name =
			makeLabel(selectButton, displayName, UDim2.new(0.5, 0, 0, 26), nameColor, Enum.Font.GothamBold)
		name.Position = UDim2.fromOffset(12, 6)
		name.TextSize = 15

		local badgeText = if selected then "SELECTED  ✓" else "TAP TO SELECT"
		local badgeColor = if selected then COLORS.Lime else COLORS.Muted
		local badge =
			makeLabel(selectButton, badgeText, UDim2.new(0.48, 0, 0, 18), badgeColor, Enum.Font.GothamBold)
		badge.Position = UDim2.new(0.52, -6, 0, 10)
		badge.TextXAlignment = Enum.TextXAlignment.Right
		badge.TextSize = 10

		local roleText = mutant.Role or "Striker"
		local now = os.time()
		local isResting = mutant.RestUntil and mutant.RestUntil > now
		local restSuffix = if isResting
			then string.format(" • ⏳ REST (%ds)", math.max(1, mutant.RestUntil - now))
			else ""
		local detail = makeLabel(
			selectButton,
			string.format(
				"Tier %s • Lv.%s • %s%s",
				tostring(mutant.Tier),
				tostring(mutant.Level),
				roleText,
				restSuffix
			),
			UDim2.new(1, -16, 0, 20),
			if isResting then COLORS.Orange else COLORS.Muted,
			Enum.Font.Gotham
		)
		detail.Position = UDim2.fromOffset(12, 30)
		detail.TextSize = 11
		detail.TextTruncate = Enum.TextTruncate.AtEnd

		local calculated = MutantStats.CalculateStats(mutant.Tier, mutant.Genes or {}, mutant.Role)
		local geneCount = if mutant.Genes then #mutant.Genes else 0
		local statsSummary = makeLabel(
			selectButton,
			string.format(
				"❤️ %d  ⚔️ %d  ⚡ %d  •  🧬 %d gene(s)",
				calculated.MaxHp,
				calculated.Attack,
				calculated.Speed,
				geneCount
			),
			UDim2.new(1, -16, 0, 18),
			COLORS.Cyan,
			Enum.Font.GothamBold
		)
		statsSummary.Position = UDim2.fromOffset(12, 54)
		statsSummary.TextSize = 11

		selectButton.Activated:Connect(function()
			self:_toggleSelected(mutant.Id)
		end)

		local infoBtn = Instance.new("TextButton")
		infoBtn.AnchorPoint = Vector2.new(1, 0.5)
		infoBtn.Position = UDim2.new(1, -48, 0.5, 0)
		infoBtn.Size = UDim2.fromOffset(38, 38)
		infoBtn.BackgroundColor3 = Color3.fromRGB(25, 48, 60)
		infoBtn.Text = "INFO"
		infoBtn.TextColor3 = COLORS.Cyan
		infoBtn.Font = Enum.Font.GothamBold
		infoBtn.TextSize = 10
		infoBtn.Parent = card
		addCorner(infoBtn, 8)
		addStroke(infoBtn, COLORS.Cyan, 1, 0.5)
		infoBtn.Activated:Connect(function()
			self:_showStats(mutant)
		end)

		local release = Instance.new("TextButton")
		release.AnchorPoint = Vector2.new(1, 0.5)
		release.Position = UDim2.new(1, -6, 0.5, 0)
		release.Size = UDim2.fromOffset(38, 38)
		release.BackgroundColor3 = Color3.fromRGB(75, 43, 49)
		release.Text = "×"
		release.TextColor3 = COLORS.Red
		release.Font = Enum.Font.GothamBold
		release.TextSize = 24
		release.Parent = card
		addCorner(release, 8)
		local activeBattle = type(self._state.Battle) == "table" and self._state.Battle.MutantId == mutant.Id
		local tutorialComplete = self._state.Tutorial and self._state.Tutorial.TutorialCompleted
		local canRelease = tutorialComplete and #self._state.Mutants > 1 and not activeBattle
		release.Active = canRelease
		release.AutoButtonColor = canRelease
		release.TextTransparency = if canRelease then 0 else 0.65
		release.Activated:Connect(function()
			if canRelease and not self._busy then
				self:_playSound("Click")
				self:_showRelease(mutant.Id)
			end
		end)
	end
end

function UIController:_tutorialHint()
	if not self._state then
		return "Connecting to your research session..."
	end
	local tutorial = self._state.Tutorial or {}
	if not tutorial.FirstBlobCreated then
		return "Step 1: Click CREATE BLOB to synthesize your first free specimen."
	elseif not tutorial.FirstMergeCompleted then
		if (tutorial.FreeBlobsClaimed or 0) < self._gameConfig.FreeTutorialBlobs then
			return "Step 2: Click CREATE BLOB to synthesize your second specimen."
		end
		return "Step 2: Click BOTH Blob cards above to select them, then press MERGE SELECTED."
	elseif not tutorial.TutorialCompleted then
		if type(self._state.Battle) == "table" then
			return "Training in progress! Watch the combat dummy in the chamber."
		end
		return "Step 3: Select your Toxic Blob or Plasma Blob, then click START TRAINING."
	end
	return "Tutorial complete! Grow your collection, synthesize mutations and train mutants."
end

function UIController:_pruneSelection()
	if not self._state then
		return
	end
	local valid = {}
	for _, selectedId in self._selected do
		for _, mutant in self._state.Mutants or {} do
			if mutant.Id == selectedId then
				table.insert(valid, selectedId)
				break
			end
		end
	end
	self._selected = valid
	if self._callbacks.OnSelectionChanged then
		self._callbacks.OnSelectionChanged(self._selected)
	end
end

function UIController:SetState(snapshot)
	self._state = snapshot
	self:_pruneSelection()
	self._balance.Text = string.format("◉  %s", tostring(snapshot.BioCoins or 0))
	self._inventoryTitle.Text = string.format(
		"SPECIMENS %d/%d  •  SELECT UP TO 2",
		#(snapshot.Mutants or {}),
		snapshot.SlotsUnlocked or 0
	)
	self._hint.Text = self:_tutorialHint()
	self._mode.Text = "Persistence: " .. tostring(snapshot.PersistenceMode or "Unknown")
	local freeRemaining = math.max(
		0,
		self._gameConfig.FreeTutorialBlobs - ((snapshot.Tutorial and snapshot.Tutorial.FreeBlobsClaimed) or 0)
	)
	if freeRemaining > 0 then
		self._create.Text = string.format("CREATE BLOB  •  FREE (%d LEFT)", freeRemaining)
	else
		self._create.Text = string.format("CREATE BLOB  •  %d BIOCOINS", self._gameConfig.BlobPrice)
	end
	self:_renderInventory()
	self:_refreshControls()
	if self._squadUI then
		self._squadUI:SetState(snapshot)
	end
	if self._combatUI then
		local inExpedition = snapshot.Expedition ~= nil
			and (
				snapshot.Expedition.InCombat
				or snapshot.Expedition.Status == "AtTerminal"
				or snapshot.Expedition.Status == "Exploring"
			)
		if inExpedition then
			self._panel.Visible = false
			self._combatUI:UpdateCombat(snapshot.Expedition.CurrentCombat, snapshot.Expedition)
		else
			self._panel.Visible = true
			self._combatUI:SetVisible(false)
		end
	end
end

function UIController:SetStatus(status, detail)
	if status == "ready" then
		self._status.Visible = false
		self._retry.Visible = false
		return
	end
	self._status.Visible = true
	if status == "loading" then
		self._status.Text = detail or "Connecting to the lab..."
		self._status.TextColor3 = COLORS.Orange
		self._retry.Visible = false
	else
		local friendly = ERROR_TEXT[detail] or "Connection delayed. Automatic retry is active."
		self._status.Text = friendly
		self._status.TextColor3 = COLORS.Red
		self._retry.Visible = true
	end
end

function UIController:SetBusy(busy)
	self._busy = busy
	self:_refreshControls()
end

function UIController:_refreshControls()
	local ready = self._state ~= nil and not self._busy
	local count = if self._state then #(self._state.Mutants or {}) else 0
	local slots = if self._state then (self._state.SlotsUnlocked or 0) else 0
	setEnabled(self._create, ready and count < slots, COLORS.Cyan)
	setEnabled(self._merge, ready and #self._selected == 2, COLORS.Purple)
	if self._breedBtn then
		setEnabled(self._breedBtn, ready and #self._selected == 2, COLORS.Lime)
	end
	local noBattle = self._state and self._state.Battle == false
	setEnabled(self._battleButton, ready and #self._selected == 1 and noBattle, COLORS.Orange)
	if self._busy then
		self._status.Visible = true
		self._status.Text = "Processing experiment..."
		self._status.TextColor3 = COLORS.Cyan
	elseif self._state and self._status.Text == "Processing experiment..." then
		self._status.Visible = false
	end
end

function UIController:_updateBattleClock()
	if not self._state or type(self._state.Battle) ~= "table" then
		self._battleStatus.Text = "No active training battle"
		self._battleStatus.TextColor3 = COLORS.Muted
		return
	end
	local remaining = math.max(0, self._state.Battle.EndsAt - workspace:GetServerTimeNow())
	self._battleStatus.Text =
		string.format("TRAINING  •  %.1fs  •  Reward %s", remaining, tostring(self._state.Battle.Reward))
	self._battleStatus.TextColor3 = COLORS.Orange
end

function UIController:ShowResult(action, ok, code)
	if ok then
		local expedition = self._state and self._state.Expedition
		if expedition and (action == "SelectCombatAction" or action == "ProceedNextRoom") then
			if expedition.Status == "Completed" then
				self:_playSound("Victory")
				self:ShowToast(
					"Expedition complete! Loot collected. Squad resting for 2 minutes.",
					COLORS.Lime
				)
				return
			elseif expedition.Status == "Failed" then
				self:ShowToast(
					"Expedition lost. Secured loot is safe; your squad can try again now.",
					COLORS.Orange
				)
				return
			end
		end
		local messages = {
			CreateBlob = "New Blob stabilized.",
			Merge = "Merge successful! Evolution completed.",
			BreedMutants = "Genetic synthesis complete! Genes inherited.",
			StartBattle = "Training started.",
			StartExpedition = "Expedition squad deployed!",
			SecureLoot = "Loot secured at expedition terminal.",
			Evacuate = "Squad evacuated! Secured loot transferred.",
			ProceedNextRoom = "Advancing to next expedition chamber.",
			ReleaseMutant = "Specimen released. No refund was issued.",
		}
		if action == "CreateBlob" then
			self:_playSound("Create")
		elseif action == "Merge" or action == "BreedMutants" then
			self:_playSound("Merge")
		elseif action == "StartBattle" or action == "StartExpedition" then
			self:_playSound("Battle")
		else
			self:_playSound("Click")
		end
		self:ShowToast(messages[action] or "Experiment complete.", COLORS.Cyan)
		return
	end
	self:_playSound("Error")
	self:ShowToast(ERROR_TEXT[code] or ("Request failed: " .. tostring(code)), COLORS.Red)
end

function UIController:ShowNotice(notice)
	if notice.Code == "BATTLE_COMPLETE" then
		self:_playSound("Victory")
		self:ShowToast(
			string.format("Training complete! +%s BioCoins", tostring(notice.Reward or 0)),
			COLORS.Lime
		)
	end
end

function UIController:ShowToast(text, color)
	self._toastGeneration += 1
	local generation = self._toastGeneration
	self._toast.Text = text
	self._toast.TextColor3 = color or COLORS.Text
	self._toast.Visible = true
	task.delay(3.2, function()
		if self._toastGeneration == generation then
			self._toast.Visible = false
		end
	end)
end

function UIController:Destroy()
	if self._squadUI then
		self._squadUI:Destroy()
	end
	if self._combatUI then
		self._combatUI:Destroy()
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._screen then
		self._screen:Destroy()
	end
end

return UIController
