--!strict

local isRoblox = typeof(script) == "Instance" and typeof(game) == "Instance"
local root = if isRoblox then game:GetService("ReplicatedStorage"):WaitForChild("MutantLab") else nil
local shared = if root then root:WaitForChild("Shared") else nil

local CombatEngine = if isRoblox
	then require(shared.Combat.CombatEngine)
	else require("../../shared/Combat/CombatEngine")
local CombatTypes = if isRoblox
	then require(shared.Types.CombatTypes)
	else require("../../shared/Types/CombatTypes")
local ExpeditionGenerator = if isRoblox
	then require(script.Parent.ExpeditionGenerator)
	else require("./ExpeditionGenerator")
local ExpeditionTypes = if isRoblox
	then require(shared.Types.ExpeditionTypes)
	else require("../../shared/Types/ExpeditionTypes")

type SquadInput = CombatTypes.SquadInput
type CombatAction = CombatTypes.CombatAction
type CombatState = CombatTypes.CombatState
type LootBundle = ExpeditionTypes.LootBundle
type ExpeditionRoom = ExpeditionTypes.ExpeditionRoom
type ExpeditionStatus = ExpeditionTypes.ExpeditionStatus
type ExpeditionSnapshot = ExpeditionTypes.ExpeditionSnapshot

local ExpeditionSession = {}
ExpeditionSession.__index = ExpeditionSession

export type SessionOptions = {
	Rng: (() -> number)?,
}

export type ExpeditionSessionInstance = {
	Id: string,
	TotalRooms: number,
	CurrentRoomIndex: number,
	Rooms: { ExpeditionRoom },
	PlayerSquad: SquadInput,
	CurrentCombat: CombatState?,
	PendingLoot: LootBundle,
	SecuredLoot: LootBundle,
	Status: ExpeditionStatus,
	Rng: (() -> number)?,

	-- Methods
	StepCombatAction: (self: any, action: CombatAction) -> (boolean, string?),
	SecureLoot: (self: any) -> (boolean, string?),
	ProceedToNextRoom: (self: any) -> (boolean, string?),
	Evacuate: (self: any) -> (boolean, LootBundle?, string?),
	TakeUncreditedLoot: (self: any) -> LootBundle,
	GetSnapshot: (self: any) -> ExpeditionSnapshot,
}

local function mergeLoot(target: LootBundle, source: LootBundle)
	target.BioCoins += source.BioCoins
	target.DnaFragments += source.DnaFragments
	for _, item in source.Items do
		table.insert(target.Items, item)
	end
end

-- Section 5.4: Between combats, restore full HP to player squad
local function restoreSquadHp(combatState: CombatState)
	for _, u in combatState.PlayerTeam.Active do
		u.CurrentHp = u.MaxHp
		u.IsAlive = true
	end
	for _, u in combatState.PlayerTeam.Reserve do
		u.CurrentHp = u.MaxHp
		u.IsAlive = true
	end
end

local function findUnitInCombat(state: CombatState, unitId: string): (any?, string?)
	for _, u in state.PlayerTeam.Active do
		if u.Id == unitId then
			return u, "Player"
		end
	end
	for _, u in state.PlayerTeam.Reserve do
		if u.Id == unitId then
			return u, "Player"
		end
	end
	for _, u in state.EnemyTeam.Active do
		if u.Id == unitId then
			return u, "Enemy"
		end
	end
	for _, u in state.EnemyTeam.Reserve do
		if u.Id == unitId then
			return u, "Enemy"
		end
	end
	return nil, nil
end

local function processEnemyTurns(self: any)
	if not self.CurrentCombat or self.CurrentCombat.Status ~= "InProgress" then
		return
	end

	local maxEnemySteps = 30
	local steps = 0

	while self.CurrentCombat.Status == "InProgress" and steps < maxEnemySteps do
		local currentUnitId = self.CurrentCombat.CurrentTurnUnitId
		if not currentUnitId or currentUnitId == "" then
			break
		end

		local unit, side = findUnitInCombat(self.CurrentCombat, currentUnitId)
		if not unit or side ~= "Enemy" then
			-- It is the player unit's turn, halt so player can act!
			break
		end

		local team = self.CurrentCombat.EnemyTeam
		local chosenAbilityType: CombatTypes.AbilityType = "Basic"

		for _, ab in unit.Abilities do
			local cd = unit.Cooldowns[ab.Name] or 0
			if ab.Type == "Ultimate" and team.Energy >= ab.EnergyCost and cd == 0 then
				chosenAbilityType = "Ultimate"
				break
			elseif ab.Type == "RoleSkill" and team.Energy >= ab.EnergyCost and cd == 0 then
				chosenAbilityType = "RoleSkill"
			end
		end

		local targetId: string? = nil
		local livingPlayerUnits = {}
		for _, u in self.CurrentCombat.PlayerTeam.Active do
			if u.IsAlive and u.CurrentHp > 0 then
				table.insert(livingPlayerUnits, u)
			end
		end

		if #livingPlayerUnits > 0 then
			table.sort(livingPlayerUnits, function(a, b)
				return a.CurrentHp < b.CurrentHp
			end)
			targetId = livingPlayerUnits[1].Id
		end

		local enemyAction: CombatTypes.CombatAction = {
			ActorId = unit.Id,
			AbilityType = chosenAbilityType,
			TargetId = targetId,
		}

		local stepOk, _ = CombatEngine.Step(self.CurrentCombat, enemyAction, { Rng = self.Rng })
		if not stepOk then
			break
		end
		steps += 1
	end
end

function ExpeditionSession.new(
	id: string,
	playerSquad: SquadInput,
	roomCount: number,
	options: SessionOptions?
): ExpeditionSessionInstance
	local rng = if options and options.Rng then options.Rng else math.random
	local rooms = ExpeditionGenerator.GenerateChain(roomCount, rng)

	local self = setmetatable({}, ExpeditionSession)
	self.Id = id
	self.TotalRooms = roomCount
	self.CurrentRoomIndex = 1
	self.Rooms = rooms
	self.PlayerSquad = playerSquad
	self.PendingLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
	self.SecuredLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
	self._creditedLoot = { BioCoins = 0, DnaFragments = 0, ItemsCount = 0 }
	self.Status = "InCombat"
	self.Rng = rng

	-- Initialize Room 1 combat
	local room1 = rooms[1]
	if room1.EnemySquad then
		self.CurrentCombat = CombatEngine.Init(playerSquad, room1.EnemySquad, { Rng = rng })
		processEnemyTurns(self)
	end

	return (self :: any) :: ExpeditionSessionInstance
end

local function advanceRoom(self: any): (boolean, string?)
	if self.CurrentRoomIndex >= self.TotalRooms then
		self.Status = "Completed"
		return true, nil
	end

	self.CurrentRoomIndex += 1
	local nextRoom = self.Rooms[self.CurrentRoomIndex]

	if nextRoom.EnemySquad then
		self.CurrentCombat = CombatEngine.Init(self.PlayerSquad, nextRoom.EnemySquad, { Rng = self.Rng })
		self.Status = "InCombat"
		processEnemyTurns(self)
	else
		self.CurrentCombat = nil
		self.Status = if nextRoom.HasTerminal then "AtTerminal" else "Exploring"
	end

	return true, nil
end

function ExpeditionSession:_handleVictory()
	if not self.CurrentCombat then
		return
	end
	local currentRoom = self.Rooms[self.CurrentRoomIndex]
	mergeLoot(self.PendingLoot, currentRoom.Loot)
	restoreSquadHp(self.CurrentCombat)

	if currentRoom.HasTerminal then
		self.Status = "AtTerminal"
	else
		advanceRoom(self)
	end
end

function ExpeditionSession:_handleDefeat()
	self.Status = "Failed"
	self.PendingLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
end

function ExpeditionSession:StepCombatAction(action: CombatAction): (boolean, string?)
	if self.Status ~= "InCombat" then
		return false, "NOT_IN_COMBAT"
	end
	if not self.CurrentCombat then
		return false, "NO_ACTIVE_COMBAT"
	end

	if not action.ActorId or action.ActorId == "" then
		action.ActorId = self.CurrentCombat.CurrentTurnUnitId
	end

	local ok, err = CombatEngine.Step(self.CurrentCombat, action, { Rng = self.Rng })
	if not ok then
		return false, err
	end

	if self.CurrentCombat.Status == "Victory" then
		self:_handleVictory()
		return true, nil
	elseif self.CurrentCombat.Status == "Defeat" then
		self:_handleDefeat()
		return true, nil
	end

	processEnemyTurns(self)

	if self.CurrentCombat.Status == "Victory" then
		self:_handleVictory()
		return true, nil
	elseif self.CurrentCombat.Status == "Defeat" then
		self:_handleDefeat()
		return true, nil
	end

	return true, nil
end

function ExpeditionSession:SecureLoot(): (boolean, string?)
	if self.Status ~= "AtTerminal" then
		return false, "NOT_AT_TERMINAL"
	end

	mergeLoot(self.SecuredLoot, self.PendingLoot)
	self.PendingLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
	return true, nil
end

function ExpeditionSession:ProceedToNextRoom(): (boolean, string?)
	if self.Status ~= "AtTerminal" then
		return false, "CANNOT_PROCEED"
	end

	return advanceRoom(self)
end

function ExpeditionSession:Evacuate(): (boolean, LootBundle?, string?)
	if self.Status ~= "AtTerminal" then
		return false, nil, "CANNOT_EVACUATE"
	end

	-- Add any remaining pending loot to secured
	mergeLoot(self.SecuredLoot, self.PendingLoot)
	self.PendingLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
	self.Status = "Completed"

	return true, self.SecuredLoot, nil
end

function ExpeditionSession:TakeUncreditedLoot(): LootBundle
	local uncredited: LootBundle = {
		BioCoins = math.max(0, self.SecuredLoot.BioCoins - self._creditedLoot.BioCoins),
		DnaFragments = math.max(0, self.SecuredLoot.DnaFragments - self._creditedLoot.DnaFragments),
		Items = {},
	}
	for i = self._creditedLoot.ItemsCount + 1, #self.SecuredLoot.Items do
		table.insert(uncredited.Items, self.SecuredLoot.Items[i])
	end
	self._creditedLoot.BioCoins = self.SecuredLoot.BioCoins
	self._creditedLoot.DnaFragments = self.SecuredLoot.DnaFragments
	self._creditedLoot.ItemsCount = #self.SecuredLoot.Items
	return uncredited
end

function ExpeditionSession:GetSnapshot(): ExpeditionSnapshot
	local currentRoom = self.Rooms[self.CurrentRoomIndex]
	return {
		Id = self.Id,
		TotalRooms = self.TotalRooms,
		CurrentRoomIndex = self.CurrentRoomIndex,
		Status = self.Status,
		RoomTitle = currentRoom.Title,
		RoomType = currentRoom.Type,
		HasTerminal = currentRoom.HasTerminal,
		PendingLoot = {
			BioCoins = self.PendingLoot.BioCoins,
			DnaFragments = self.PendingLoot.DnaFragments,
			Items = table.clone(self.PendingLoot.Items),
		},
		SecuredLoot = {
			BioCoins = self.SecuredLoot.BioCoins,
			DnaFragments = self.SecuredLoot.DnaFragments,
			Items = table.clone(self.SecuredLoot.Items),
		},
		InCombat = self.Status == "InCombat",
		CurrentCombat = self.CurrentCombat,
	}
end

return ExpeditionSession
