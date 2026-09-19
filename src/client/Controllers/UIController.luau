--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local ERROR_TEXT = {
	NOT_READY = "The lab is still loading. Try again in a moment.",
	RATE_LIMITED = "Too many experiments at once. Slow down.",
	INVALID_REQUEST = "That request was not understood.",
	INSUFFICIENT_FUNDS = "You need more BioCoins.",
	INVENTORY_FULL = "Your mutant slots are full.",
	INVALID_MERGE = "Select two compatible Blobs to merge.",
	MUTANT_NOT_FOUND = "That mutant is no longer available.",
	MUTANT_BUSY = "That mutant is currently battling.",
	BATTLE_RUNNING = "A training battle is already running.",
	TUTORIAL_REQUIRED = "Follow the current tutorial step first.",
	LAST_MUTANT = "You cannot release your last mutant.",
	INTERNAL_ERROR = "The lab hit an internal error. Please retry.",
	CONNECTION_ERROR = "Connection lost. Please retry.",
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
	self:_build()
	return self
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
		makeLabel(header, "MUTANT LAB", UDim2.new(0.58, 0, 0, 28), COLORS.Text, Enum.Font.GothamBlack)
	title.TextSize = 21
	local subtitle = makeLabel(
		header,
		"BIO RESEARCH TERMINAL",
		UDim2.new(0.65, 0, 0, 20),
		COLORS.Muted,
		Enum.Font.GothamMedium
	)
	subtitle.Position = UDim2.fromOffset(0, 29)
	subtitle.TextSize = 10
	subtitle.TextTransparency = 0.1

	local balance = makeLabel(header, "◉  --", UDim2.new(0.42, 0, 0, 36), COLORS.Lime, Enum.Font.GothamBold)
	balance.Position = UDim2.new(0.58, 0, 0, 4)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	balance.TextSize = 18
	self._balance = balance

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
			self._callbacks.OnAction("CreateBlob", nil)
		end
	end)
	self._create = create

	local merge = makeButton(scroll, "MERGE SELECTED", COLORS.Purple)
	merge.LayoutOrder = 8
	merge.Activated:Connect(function()
		if not self._busy and #self._selected == 2 then
			self._callbacks.OnAction("Merge", { FirstId = self._selected[1], SecondId = self._selected[2] })
		end
	end)
	self._merge = merge

	local battle = makeButton(scroll, "START TRAINING", COLORS.Orange)
	battle.LayoutOrder = 9
	battle.Activated:Connect(function()
		if not self._busy and #self._selected == 1 then
			self._callbacks.OnAction("StartBattle", { MutantId = self._selected[1] })
		end
	end)
	self._battleButton = battle

	local battleStatus = makeLabel(
		scroll,
		"No active training battle",
		UDim2.new(1, 0, 0, 42),
		COLORS.Muted,
		Enum.Font.GothamMedium
	)
	battleStatus.LayoutOrder = 10
	battleStatus.BackgroundColor3 = COLORS.PanelSoft
	battleStatus.BackgroundTransparency = 0.1
	battleStatus.TextXAlignment = Enum.TextXAlignment.Center
	battleStatus.TextSize = 13
	addCorner(battleStatus, 9)
	self._battleStatus = battleStatus

	local mode = makeLabel(scroll, "Persistence: --", UDim2.new(1, 0, 0, 22), COLORS.Muted, Enum.Font.Gotham)
	mode.LayoutOrder = 11
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
		if viewport.X < 600 and viewport.Y > viewport.X then
			panel.AnchorPoint = Vector2.new(1, 1)
			panel.Position = UDim2.new(1, -10, 1, -10)
			panel.Size = UDim2.new(1, -20, 0.58, 0)
		else
			local width = if viewport.X < 700
				then math.floor(math.clamp(viewport.X * 0.68, 300, 350))
				else math.floor(math.clamp(viewport.X * 0.34, 350, 420))
			panel.AnchorPoint = Vector2.new(1, 0)
			panel.Position = UDim2.new(1, -10, 0, 10)
			panel.Size = UDim2.new(0, width, 1, -20)
		end
	end
	resize()
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

function UIController:_isSelected(mutantId)
	return table.find(self._selected, mutantId) ~= nil
end

function UIController:_toggleSelected(mutantId)
	local index = table.find(self._selected, mutantId)
	if index then
		table.remove(self._selected, index)
	elseif #self._selected < 2 then
		table.insert(self._selected, mutantId)
	else
		self:ShowToast("You can select at most two specimens.", COLORS.Orange)
	end
	self:_renderInventory()
	self:_refreshControls()
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
		card.Size = UDim2.new(1, 0, 0, 72)
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
		selectButton.Size = UDim2.new(1, -58, 1, 0)
		selectButton.Text = ""
		selectButton.Parent = card
		local name = makeLabel(
			selectButton,
			if mutant.Type == "ToxicBlob" then "TOXIC BLOB" else "BLOB",
			UDim2.new(1, -16, 0, 28),
			if mutant.Type == "ToxicBlob" then COLORS.Lime else COLORS.Cyan,
			Enum.Font.GothamBold
		)
		name.Position = UDim2.fromOffset(12, 8)
		name.TextSize = 15
		local detail = makeLabel(
			selectButton,
			string.format("Tier %s  •  Level %s", tostring(mutant.Tier), tostring(mutant.Level)),
			UDim2.new(1, -16, 0, 22),
			COLORS.Muted,
			Enum.Font.Gotham
		)
		detail.Position = UDim2.fromOffset(12, 37)
		detail.TextSize = 11
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		selectButton.Activated:Connect(function()
			self:_toggleSelected(mutant.Id)
		end)

		local release = Instance.new("TextButton")
		release.AnchorPoint = Vector2.new(1, 0.5)
		release.Position = UDim2.new(1, -9, 0.5, 0)
		release.Size = UDim2.fromOffset(42, 42)
		release.BackgroundColor3 = Color3.fromRGB(75, 43, 49)
		release.Text = "×"
		release.TextColor3 = COLORS.Red
		release.Font = Enum.Font.GothamBold
		release.TextSize = 25
		release.Parent = card
		addCorner(release, 9)
		local activeBattle = type(self._state.Battle) == "table" and self._state.Battle.MutantId == mutant.Id
		local tutorialComplete = self._state.Tutorial and self._state.Tutorial.TutorialCompleted
		local canRelease = tutorialComplete and #self._state.Mutants > 1 and not activeBattle
		release.Active = canRelease
		release.AutoButtonColor = canRelease
		release.TextTransparency = if canRelease then 0 else 0.65
		release.Activated:Connect(function()
			if canRelease and not self._busy then
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
		return "Step 1: create your first free Blob."
	elseif not tutorial.FirstMergeCompleted then
		if (tutorial.FreeBlobsClaimed or 0) < self._gameConfig.FreeTutorialBlobs then
			return "Step 2: create one more free Blob, then select both."
		end
		return "Step 2: select two Blobs and merge them into a Toxic Blob."
	elseif not tutorial.TutorialCompleted then
		if type(self._state.Battle) == "table" then
			return "Training in progress. Watch the combat dummy!"
		end
		return "Step 3: select the Toxic Blob and start training."
	end
	return "Tutorial complete. Grow your collection and train your mutants."
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
		local messages = {
			CreateBlob = "New Blob stabilized.",
			Merge = "Merge successful. Toxic Blob created!",
			StartBattle = "Training started.",
			ReleaseMutant = "Specimen released. No refund was issued.",
		}
		self:ShowToast(messages[action] or "Experiment complete.", COLORS.Cyan)
		return
	end
	self:ShowToast(ERROR_TEXT[code] or ("Request failed: " .. tostring(code)), COLORS.Red)
end

function UIController:ShowNotice(notice)
	if notice.Code == "BATTLE_COMPLETE" then
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
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._screen then
		self._screen:Destroy()
	end
end

return UIController
