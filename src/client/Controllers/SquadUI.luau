--!nonstrict

local SquadUI = {}
SquadUI.__index = SquadUI

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

function SquadUI.new(parentGui, callbacks)
	local self = setmetatable({}, SquadUI)
	self.ParentGui = parentGui
	self.Callbacks = callbacks or {}
	self.ActiveSlots = {} -- { mutantId, mutantId, mutantId }
	self.ReserveSlots = {} -- { mutantId, mutantId, mutantId }
	self.SelectedRoomCount = 3
	self.CurrentSnapshot = nil

	local modal = Instance.new("Frame")
	modal.Name = "SquadModal"
	modal.Size = UDim2.new(0, 560, 0, 420)
	modal.Position = UDim2.new(0.5, -280, 0.5, -210)
	modal.BackgroundColor3 = COLORS.Panel
	modal.Visible = false
	modal.Parent = parentGui
	addCorner(modal, 12)
	addStroke(modal, COLORS.PanelSoft, 2)
	self.Modal = modal

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -40, 0, 36)
	header.Position = UDim2.new(0, 20, 0, 10)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.TextColor3 = COLORS.Cyan
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "ASSEMBLE EXPEDITION SQUAD"
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0, 14)
	closeBtn.BackgroundColor3 = COLORS.PanelSoft
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = COLORS.Muted
	closeBtn.Text = "X"
	closeBtn.Parent = modal
	addCorner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function()
		self:SetVisible(false)
	end)

	-- Squad Slots Container (Active 3 + Reserve 3)
	local slotsLabel = Instance.new("TextLabel")
	slotsLabel.Size = UDim2.new(1, -40, 0, 20)
	slotsLabel.Position = UDim2.new(0, 20, 0, 50)
	slotsLabel.BackgroundTransparency = 1
	slotsLabel.Font = Enum.Font.Gotham
	slotsLabel.TextSize = 12
	slotsLabel.TextColor3 = COLORS.Muted
	slotsLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotsLabel.Text = "FRONTLINE SQUAD (UP TO 3 ACTIVE) & REINFORCEMENTS (UP TO 3 RESERVE)"
	slotsLabel.Parent = modal

	local slotsGrid = Instance.new("Frame")
	slotsGrid.Name = "SlotsGrid"
	slotsGrid.Size = UDim2.new(1, -40, 0, 90)
	slotsGrid.Position = UDim2.new(0, 20, 0, 72)
	slotsGrid.BackgroundTransparency = 1
	slotsGrid.Parent = modal
	self.SlotsGrid = slotsGrid

	local slotsLayout = Instance.new("UIGridLayout")
	slotsLayout.CellSize = UDim2.new(0, 80, 0, 84)
	slotsLayout.CellPadding = UDim2.new(0, 8, 0, 0)
	slotsLayout.Parent = slotsGrid

	-- Available Mutants List
	local poolLabel = Instance.new("TextLabel")
	poolLabel.Size = UDim2.new(1, -40, 0, 20)
	poolLabel.Position = UDim2.new(0, 20, 0, 170)
	poolLabel.BackgroundTransparency = 1
	poolLabel.Font = Enum.Font.Gotham
	poolLabel.TextSize = 12
	poolLabel.TextColor3 = COLORS.Muted
	poolLabel.TextXAlignment = Enum.TextXAlignment.Left
	poolLabel.Text = "AVAILABLE MUTANTS IN LAB (TAP TO ADD / REMOVE)"
	poolLabel.Parent = modal

	local poolScroll = Instance.new("ScrollingFrame")
	poolScroll.Name = "PoolScroll"
	poolScroll.Size = UDim2.new(1, -40, 0, 120)
	poolScroll.Position = UDim2.new(0, 20, 0, 192)
	poolScroll.BackgroundColor3 = COLORS.PanelSoft
	poolScroll.ScrollBarThickness = 3
	poolScroll.Parent = modal
	addCorner(poolScroll, 8)
	self.PoolScroll = poolScroll

	local poolLayout = Instance.new("UIGridLayout")
	poolLayout.CellSize = UDim2.new(0, 120, 0, 52)
	poolLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	poolLayout.Parent = poolScroll

	-- Expedition Type Switcher (3 vs 5 rooms)
	local type3Btn = Instance.new("TextButton")
	type3Btn.Size = UDim2.new(0, 140, 0, 36)
	type3Btn.Position = UDim2.new(0, 20, 1, -50)
	type3Btn.BackgroundColor3 = COLORS.Cyan
	type3Btn.Font = Enum.Font.GothamBold
	type3Btn.TextSize = 12
	type3Btn.TextColor3 = COLORS.Panel
	type3Btn.Text = "3 ROOMS (SCOUT)"
	type3Btn.Parent = modal
	addCorner(type3Btn, 8)
	self.Type3Btn = type3Btn

	local type5Btn = Instance.new("TextButton")
	type5Btn.Size = UDim2.new(0, 140, 0, 36)
	type5Btn.Position = UDim2.new(0, 170, 1, -50)
	type5Btn.BackgroundColor3 = COLORS.Card
	type5Btn.Font = Enum.Font.GothamBold
	type5Btn.TextSize = 12
	type5Btn.TextColor3 = COLORS.Text
	type5Btn.Text = "5 ROOMS (VAULT)"
	type5Btn.Parent = modal
	addCorner(type5Btn, 8)
	self.Type5Btn = type5Btn

	type3Btn.MouseButton1Click:Connect(function()
		self.SelectedRoomCount = 3
		type3Btn.BackgroundColor3 = COLORS.Cyan
		type3Btn.TextColor3 = COLORS.Panel
		type5Btn.BackgroundColor3 = COLORS.Card
		type5Btn.TextColor3 = COLORS.Text
	end)

	type5Btn.MouseButton1Click:Connect(function()
		self.SelectedRoomCount = 5
		type5Btn.BackgroundColor3 = COLORS.Purple
		type5Btn.TextColor3 = COLORS.Panel
		type3Btn.BackgroundColor3 = COLORS.Card
		type3Btn.TextColor3 = COLORS.Text
	end)

	-- Start Expedition Button
	local deployBtn = Instance.new("TextButton")
	deployBtn.Size = UDim2.new(0, 180, 0, 36)
	deployBtn.Position = UDim2.new(1, -200, 1, -50)
	deployBtn.BackgroundColor3 = COLORS.Lime
	deployBtn.Font = Enum.Font.GothamBold
	deployBtn.TextSize = 13
	deployBtn.TextColor3 = COLORS.Panel
	deployBtn.Text = "START EXPEDITION"
	deployBtn.Parent = modal
	addCorner(deployBtn, 8)
	self.DeployBtn = deployBtn

	deployBtn.MouseButton1Click:Connect(function()
		if #self.ActiveSlots == 0 then
			return
		end
		if self.Callbacks.OnDeploy then
			self.Callbacks.OnDeploy({
				RoomCount = self.SelectedRoomCount,
				ActiveIds = table.clone(self.ActiveSlots),
				ReserveIds = table.clone(self.ReserveSlots),
			})
			self:SetVisible(false)
		end
	end)

	return self
end

function SquadUI:SetVisible(visible)
	self.Modal.Visible = visible
	if visible and self.CurrentSnapshot then
		self:Refresh()
	end
end

function SquadUI:SetState(snapshot)
	self.CurrentSnapshot = snapshot
	if self.Modal.Visible then
		self:Refresh()
	end
end

function SquadUI:Refresh()
	if not self.CurrentSnapshot then
		return
	end

	-- Render 6 Slots
	for _, child in self.SlotsGrid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i = 1, 6 do
		local isReserve = i > 3
		local slotMutantId = if not isReserve then self.ActiveSlots[i] else self.ReserveSlots[i - 3]

		local mutantObj = nil
		if slotMutantId and self.CurrentSnapshot and self.CurrentSnapshot.Mutants then
			for _, m in ipairs(self.CurrentSnapshot.Mutants) do
				if m.Id == slotMutantId then
					mutantObj = m
					break
				end
			end
		end

		local card = Instance.new("Frame")
		card.BackgroundColor3 = if slotMutantId then COLORS.PanelSoft else Color3.fromRGB(22, 30, 38)
		card.Parent = self.SlotsGrid
		addCorner(card, 8)
		addStroke(card, if isReserve then COLORS.Purple else COLORS.Cyan, 1)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 10
		title.TextColor3 = if isReserve then COLORS.Purple else COLORS.Cyan
		title.Text = if isReserve then string.format("RESERVE %d", i - 3) else string.format("ACTIVE %d", i)
		title.Parent = card

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, 0, 0, 32)
		nameLbl.Position = UDim2.new(0, 0, 0, 18)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 11
		nameLbl.TextColor3 = COLORS.Text
		nameLbl.Text = if mutantObj
			then string.format("%s\n[%s]", mutantObj.Type, mutantObj.Role or "Striker")
			elseif slotMutantId then slotMutantId:sub(1, 8)
			else "[EMPTY]"
		nameLbl.Parent = card

		if slotMutantId then
			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(1, -8, 0, 22)
			removeBtn.Position = UDim2.new(0, 4, 1, -26)
			removeBtn.BackgroundColor3 = COLORS.Red
			removeBtn.Font = Enum.Font.GothamBold
			removeBtn.TextSize = 10
			removeBtn.TextColor3 = COLORS.Text
			removeBtn.Text = "REMOVE"
			removeBtn.Parent = card
			addCorner(removeBtn, 4)

			removeBtn.MouseButton1Click:Connect(function()
				if not isReserve then
					table.remove(self.ActiveSlots, i)
				else
					table.remove(self.ReserveSlots, i - 3)
				end
				self:Refresh()
			end)
		end
	end

	-- Render Pool
	for _, child in self.PoolScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local now = os.time()
	for _, mutant in self.CurrentSnapshot.Mutants do
		local isAssigned = table.find(self.ActiveSlots, mutant.Id) ~= nil
			or table.find(self.ReserveSlots, mutant.Id) ~= nil
		local onRest = mutant.RestUntil ~= nil and mutant.RestUntil > now

		local pCard = Instance.new("Frame")
		pCard.BackgroundColor3 = if onRest then COLORS.Disabled else COLORS.Card
		pCard.Parent = self.PoolScroll
		addCorner(pCard, 6)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 0, 20)
		lbl.Position = UDim2.new(0, 5, 0, 4)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 11
		lbl.TextColor3 = if onRest then COLORS.Muted else COLORS.Text
		lbl.Text = string.format("%s (T%d • %s)", mutant.Type, mutant.Tier, mutant.Role or "Striker")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = pCard

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(1, -10, 0, 16)
		statusLbl.Position = UDim2.new(0, 5, 0, 26)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Font = Enum.Font.Gotham
		statusLbl.TextSize = 10
		if onRest then
			statusLbl.TextColor3 = COLORS.Orange
			statusLbl.Text = string.format("RESTING (%ds)", math.max(0, mutant.RestUntil - now))
		elseif isAssigned then
			statusLbl.TextColor3 = COLORS.Lime
			statusLbl.Text = "IN SQUAD ✓"
		else
			local geneSummary = ""
			if mutant.Genes and #mutant.Genes > 0 then
				geneSummary = string.format(" • %s %d", mutant.Genes[1].Element, mutant.Genes[1].Value)
			end
			statusLbl.TextColor3 = COLORS.Cyan
			statusLbl.Text = "+ ADD TO SQUAD" .. geneSummary
		end
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.Parent = pCard

		if not onRest and not isAssigned then
			local tapBtn = Instance.new("TextButton")
			tapBtn.Size = UDim2.new(1, 0, 1, 0)
			tapBtn.BackgroundTransparency = 1
			tapBtn.Text = ""
			tapBtn.Parent = pCard
			tapBtn.MouseButton1Click:Connect(function()
				if #self.ActiveSlots < 3 then
					table.insert(self.ActiveSlots, mutant.Id)
				elseif #self.ReserveSlots < 3 then
					table.insert(self.ReserveSlots, mutant.Id)
				end
				self:Refresh()
			end)
		end
	end
end

function SquadUI:Destroy()
	if self.Modal then
		self.Modal:Destroy()
	end
end

return SquadUI
