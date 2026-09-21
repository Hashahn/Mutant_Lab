--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox
	then require(script.Parent.Parent.Types.CombatTypes)
	else require("../Types/CombatTypes")
local ElementMatrix = if isRoblox then require(script.Parent.ElementMatrix) else require("./ElementMatrix")
local MutantStats = if isRoblox then require(script.Parent.MutantStats) else require("./MutantStats")

type Element = CombatTypes.Element
type CombatRole = CombatTypes.CombatRole
type AbilityType = CombatTypes.AbilityType
type Ability = CombatTypes.Ability
type CombatUnit = CombatTypes.CombatUnit
type TeamSide = CombatTypes.TeamSide
type TeamState = CombatTypes.TeamState
type CombatAction = CombatTypes.CombatAction
type CombatLogEntry = CombatTypes.CombatLogEntry
type CombatStatus = CombatTypes.CombatStatus
type CombatState = CombatTypes.CombatState

local CombatEngine = {}

local DEFAULT_STARTING_ENERGY = 3
local DEFAULT_MAX_ENERGY = 10
local DEFAULT_PASSIVE_ENERGY = 2

export type UnitInput = {
	Id: string,
	Name: string,
	Type: string?,
	Tier: number,
	Level: number?,
	Role: CombatRole,
	Genes: { CombatTypes.Gene },
	HasVoidCore: boolean?,
}

export type EngineOptions = {
	Rng: (() -> number)?,
	StartingEnergy: number?,
	MaxEnergy: number?,
	PassiveEnergy: number?,
}

function CombatEngine.CreateUnit(input: UnitInput): CombatUnit
	local stats = MutantStats.CalculateStats(input.Tier, input.Genes, input.Role, input.Level)
	local abilities = MutantStats.BuildAbilities(input.Tier, input.Role, stats)

	return {
		Id = input.Id,
		Name = input.Name,
		Type = input.Type or input.Name,
		Tier = input.Tier,
		Level = input.Level or 1,
		Role = input.Role,
		Genes = input.Genes,
		Stats = stats,
		CurrentHp = stats.MaxHp,
		MaxHp = stats.MaxHp,
		IsAlive = true,
		HasVoidCore = input.HasVoidCore == true,
		TauntTurns = 0,
		GuardTurns = 0,
		AttackBuffTurns = 0,
		StunTurns = 0,
		Cooldowns = {},
		Abilities = abilities,
	}
end

local function findUnit(state: CombatState, unitId: string): (CombatUnit?, TeamState?)
	for _, u in state.PlayerTeam.Active do
		if u.Id == unitId then
			return u, state.PlayerTeam
		end
	end
	for _, u in state.PlayerTeam.Reserve do
		if u.Id == unitId then
			return u, state.PlayerTeam
		end
	end
	for _, u in state.EnemyTeam.Active do
		if u.Id == unitId then
			return u, state.EnemyTeam
		end
	end
	for _, u in state.EnemyTeam.Reserve do
		if u.Id == unitId then
			return u, state.EnemyTeam
		end
	end
	return nil, nil
end

local function getLivingActiveUnits(team: TeamState): { CombatUnit }
	local living = {}
	for _, u in team.Active do
		if u.IsAlive and u.CurrentHp > 0 then
			table.insert(living, u)
		end
	end
	return living
end

local function hasLivingUnits(team: TeamState): boolean
	for _, u in team.Active do
		if u.IsAlive and u.CurrentHp > 0 then
			return true
		end
	end
	for _, u in team.Reserve do
		if u.IsAlive and u.CurrentHp > 0 then
			return true
		end
	end
	return false
end

local function buildInitiativeQueue(playerTeam: TeamState, enemyTeam: TeamState): { string }
	local allLiving: { CombatUnit } = {}
	for _, u in playerTeam.Active do
		if u.IsAlive and u.CurrentHp > 0 then
			table.insert(allLiving, u)
		end
	end
	for _, u in enemyTeam.Active do
		if u.IsAlive and u.CurrentHp > 0 then
			table.insert(allLiving, u)
		end
	end

	local playerUnitIds: { [string]: boolean } = {}
	for _, u in playerTeam.Active do
		playerUnitIds[u.Id] = true
	end

	table.sort(allLiving, function(a, b)
		if a.Stats.Speed == b.Stats.Speed then
			local aIsPlayer = playerUnitIds[a.Id] == true
			local bIsPlayer = playerUnitIds[b.Id] == true
			if aIsPlayer ~= bIsPlayer then
				return aIsPlayer
			end
			return a.Id < b.Id
		end
		return a.Stats.Speed > b.Stats.Speed
	end)

	local queue: { string } = {}
	for _, u in allLiving do
		table.insert(queue, u.Id)
	end
	return queue
end

export type SquadInput = {
	Active: { UnitInput },
	Reserve: { UnitInput }?,
}

export type TeamInput = { UnitInput } | SquadInput

local function parseSquad(input: TeamInput): ({ UnitInput }, { UnitInput })
	local activeInputs: { UnitInput } = {}
	local reserveInputs: { UnitInput } = {}

	local asSquad = input :: SquadInput
	if asSquad.Active ~= nil and typeof(asSquad.Active) == "table" then
		for _, u in asSquad.Active do
			table.insert(activeInputs, u)
		end
		if asSquad.Reserve ~= nil and typeof(asSquad.Reserve) == "table" then
			for _, u in asSquad.Reserve do
				table.insert(reserveInputs, u)
			end
		end
	else
		local asList = input :: { UnitInput }
		for i, u in asList do
			if i <= 3 then
				table.insert(activeInputs, u)
			else
				table.insert(reserveInputs, u)
			end
		end
	end

	return activeInputs, reserveInputs
end

function CombatEngine.Init(
	playerUnits: TeamInput,
	enemyUnits: TeamInput,
	options: EngineOptions?
): CombatState
	local pActiveInputs, pReserveInputs = parseSquad(playerUnits)
	local eActiveInputs, eReserveInputs = parseSquad(enemyUnits)

	assert(#pActiveInputs >= 1, "Player team must have at least 1 active unit")
	assert(#eActiveInputs >= 1, "Enemy team must have at least 1 active unit")

	local startEnergy = if options and options.StartingEnergy
		then options.StartingEnergy
		else DEFAULT_STARTING_ENERGY
	local maxEnergy = if options and options.MaxEnergy then options.MaxEnergy else DEFAULT_MAX_ENERGY
	local passiveEnergy = if options and options.PassiveEnergy
		then options.PassiveEnergy
		else DEFAULT_PASSIVE_ENERGY

	local playerActive: { CombatUnit } = {}
	local playerReserve: { CombatUnit } = {}
	for _, input in pActiveInputs do
		table.insert(playerActive, CombatEngine.CreateUnit(input))
	end
	for _, input in pReserveInputs do
		table.insert(playerReserve, CombatEngine.CreateUnit(input))
	end

	local enemyActive: { CombatUnit } = {}
	local enemyReserve: { CombatUnit } = {}
	for _, input in eActiveInputs do
		table.insert(enemyActive, CombatEngine.CreateUnit(input))
	end
	for _, input in eReserveInputs do
		table.insert(enemyReserve, CombatEngine.CreateUnit(input))
	end

	local playerTeam: TeamState = {
		Side = "Player",
		Active = playerActive,
		Reserve = playerReserve,
		Energy = startEnergy,
		MaxEnergy = maxEnergy,
		PassiveEnergyPerRound = passiveEnergy,
		ReserveDeployed = false,
	}

	local enemyTeam: TeamState = {
		Side = "Enemy",
		Active = enemyActive,
		Reserve = enemyReserve,
		Energy = startEnergy,
		MaxEnergy = maxEnergy,
		PassiveEnergyPerRound = passiveEnergy,
		ReserveDeployed = false,
	}

	local queue = buildInitiativeQueue(playerTeam, enemyTeam)

	return {
		Id = "combat_" .. tostring(math.random(100000, 999999)),
		Round = 1,
		TurnIndex = 1,
		InitiativeQueue = queue,
		CurrentTurnUnitId = queue[1] or "",
		PlayerTeam = playerTeam,
		EnemyTeam = enemyTeam,
		Status = "InProgress",
		Log = {},
	}
end

local function checkAndDeployReserve(team: TeamState, log: { CombatLogEntry }, round: number): boolean
	local livingActive = getLivingActiveUnits(team)
	if #livingActive == 0 and #team.Reserve > 0 and not team.ReserveDeployed then
		-- Deploy reserve!
		team.Active = table.clone(team.Reserve)
		team.Reserve = {}
		team.ReserveDeployed = true

		table.insert(log, {
			Round = round,
			ActorId = "SYSTEM",
			ActionType = "Basic",
			TargetId = nil,
			Message = string.format("%s reserve squad has entered the battle!", team.Side),
		})
		return true
	end
	return false
end

local function updateCombatStatus(state: CombatState): CombatStatus
	local playerAlive = hasLivingUnits(state.PlayerTeam)
	local enemyAlive = hasLivingUnits(state.EnemyTeam)

	if not enemyAlive then
		state.Status = "Victory"
	elseif not playerAlive then
		state.Status = "Defeat"
	else
		state.Status = "InProgress"
	end
	return state.Status
end

local function startNewRound(state: CombatState, options: EngineOptions?)
	state.Round += 1

	-- Passive energy generation
	state.PlayerTeam.Energy =
		math.min(state.PlayerTeam.MaxEnergy, state.PlayerTeam.Energy + state.PlayerTeam.PassiveEnergyPerRound)
	state.EnemyTeam.Energy =
		math.min(state.EnemyTeam.MaxEnergy, state.EnemyTeam.Energy + state.EnemyTeam.PassiveEnergyPerRound)

	-- Decrement cooldowns and status durations
	local allTeams = { state.PlayerTeam, state.EnemyTeam }
	for _, team in allTeams do
		for _, unit in team.Active do
			if unit.TauntTurns > 0 then
				unit.TauntTurns -= 1
			end
			if unit.GuardTurns > 0 then
				unit.GuardTurns -= 1
			end
			if (unit.AttackBuffTurns or 0) > 0 then
				unit.AttackBuffTurns = (unit.AttackBuffTurns or 0) - 1
			end
			if (unit.StunTurns or 0) > 0 then
				unit.StunTurns = (unit.StunTurns or 0) - 1
			end
			for abilityName, cd in unit.Cooldowns do
				if cd > 0 then
					unit.Cooldowns[abilityName] = cd - 1
				end
			end
		end
	end

	-- Check reserve deployment for both teams before rebuilding queue
	checkAndDeployReserve(state.PlayerTeam, state.Log, state.Round)
	checkAndDeployReserve(state.EnemyTeam, state.Log, state.Round)

	-- Rebuild initiative queue
	state.InitiativeQueue = buildInitiativeQueue(state.PlayerTeam, state.EnemyTeam)
	state.TurnIndex = 1
	state.CurrentTurnUnitId = state.InitiativeQueue[1] or ""
end

local function advanceTurn(state: CombatState, options: EngineOptions?)
	local nextTurnIndex = state.TurnIndex + 1
	local foundNext = false

	while nextTurnIndex <= #state.InitiativeQueue do
		local nextId = state.InitiativeQueue[nextTurnIndex]
		local nextUnit, _ = findUnit(state, nextId)
		if nextUnit and nextUnit.IsAlive and nextUnit.CurrentHp > 0 then
			state.TurnIndex = nextTurnIndex
			state.CurrentTurnUnitId = nextId
			foundNext = true
			break
		end
		nextTurnIndex += 1
	end

	-- If all living units took their turn, advance to next round
	if not foundNext then
		startNewRound(state, options)
	end
end

function CombatEngine.Step(
	state: CombatState,
	action: CombatAction,
	options: EngineOptions?
): (boolean, string?)
	if state.Status ~= "InProgress" then
		return false, "COMBAT_ALREADY_FINISHED"
	end

	local actor, actorTeam = findUnit(state, action.ActorId)
	if not actor or not actorTeam then
		return false, "ACTOR_NOT_FOUND"
	end

	if not actor.IsAlive or actor.CurrentHp <= 0 then
		return false, "ACTOR_DEFEATED"
	end

	if actor.Id ~= state.CurrentTurnUnitId then
		return false, "NOT_ACTORS_TURN"
	end

	-- If actor is stunned, skip turn and advance
	if (actor.StunTurns or 0) > 0 then
		actor.StunTurns = (actor.StunTurns or 0) - 1
		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = "Basic",
			TargetId = nil,
			Message = string.format("%s is stunned and skipped their turn!", actor.Name),
		}
		table.insert(state.Log, logEntry)
		advanceTurn(state, options)
		updateCombatStatus(state)
		return true, nil
	end

	-- Find chosen ability
	local chosenAbility: Ability? = nil
	for _, ab in actor.Abilities do
		if ab.Type == action.AbilityType then
			chosenAbility = ab
			break
		end
	end

	if not chosenAbility then
		return false, "ABILITY_NOT_FOUND"
	end

	-- Check cooldown
	local currentCd = actor.Cooldowns[chosenAbility.Name] or 0
	if currentCd > 0 then
		return false, "ABILITY_ON_COOLDOWN"
	end

	-- Check energy
	if actorTeam.Energy < chosenAbility.EnergyCost then
		return false, "INSUFFICIENT_ENERGY"
	end

	local opponentTeam = if actorTeam.Side == "Player" then state.EnemyTeam else state.PlayerTeam
	local rng = if options and options.Rng then options.Rng else math.random

	-- Deduct energy & gain energy
	actorTeam.Energy -= chosenAbility.EnergyCost
	actorTeam.Energy = math.min(actorTeam.MaxEnergy, actorTeam.Energy + chosenAbility.EnergyGain)

	-- Set cooldown if ability has one
	if chosenAbility.Cooldown > 0 then
		actor.Cooldowns[chosenAbility.Name] = chosenAbility.Cooldown
	end

	-- Target resolution
	local target: CombatUnit? = nil
	if chosenAbility.TargetType == "SingleEnemy" then
		-- Check for enemy Taunt (Guardian role)
		local tauntingGuardian: CombatUnit? = nil
		for _, u in opponentTeam.Active do
			if u.IsAlive and u.TauntTurns > 0 then
				tauntingGuardian = u
				break
			end
		end

		if tauntingGuardian then
			target = tauntingGuardian
		elseif action.TargetId then
			local t, tTeam = findUnit(state, action.TargetId)
			if t and tTeam == opponentTeam and t.IsAlive and table.find(opponentTeam.Active, t) ~= nil then
				target = t
			end
		end

		-- Fallback to first living enemy if no valid target was provided
		if not target then
			local livingEnemies = getLivingActiveUnits(opponentTeam)
			target = livingEnemies[1]
		end

		if not target then
			return false, "NO_VALID_TARGET"
		end
	elseif chosenAbility.TargetType == "SingleAlly" then
		if action.TargetId then
			local t, tTeam = findUnit(state, action.TargetId)
			if t and tTeam == actorTeam and t.IsAlive and table.find(actorTeam.Active, t) ~= nil then
				target = t
			end
		end
		if not target then
			target = actor
		end
	elseif chosenAbility.TargetType == "Self" then
		target = actor
	end

	-- Execute ability effect
	if
		chosenAbility.Type == "Basic"
		or chosenAbility.Type == "Ultimate"
		or (chosenAbility.Type == "RoleSkill" and actor.Role == "Striker")
	then
		assert(target ~= nil, "Target required for damage ability")
		local attackElem: Element = chosenAbility.Element or actor.Stats.EffectiveElements.Primary

		local mult = ElementMatrix.GetCompositeMultiplier(
			attackElem,
			target.Stats.EffectiveElements,
			actor.HasVoidCore,
			target.HasVoidCore
		)

		-- Check passive auto-guard
		local guardRoll = rng()
		local isGuarded = guardRoll < target.Stats.AutoGuardChance
		local guardMult = if isGuarded then 0.5 else 1.0

		local attackBuff = if (actor.AttackBuffTurns or 0) > 0 then 1.35 else 1.0
		local rawDmg = actor.Stats.Attack * chosenAbility.PowerMultiplier * mult * guardMult * attackBuff
		local finalDmg = math.max(1, math.floor(rawDmg))

		target.CurrentHp = math.max(0, target.CurrentHp - finalDmg)
		if target.CurrentHp <= 0 then
			target.IsAlive = false
		end

		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = chosenAbility.Type,
			TargetId = target.Id,
			Damage = finalDmg,
			IsGuarded = isGuarded,
			ElementMultiplier = mult,
			Message = string.format(
				"%s used %s on %s for %d damage (mult: %.2f%s)",
				actor.Name,
				chosenAbility.Name,
				target.Name,
				finalDmg,
				mult,
				if isGuarded then ", GUARDED!" else ""
			),
		}
		table.insert(state.Log, logEntry)
	elseif chosenAbility.Type == "RoleSkill" and actor.Role == "Guardian" then
		-- Taunt activation
		actor.TauntTurns = 2
		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = "RoleSkill",
			TargetId = actor.Id,
			Message = string.format("%s activated Bulwark Taunt (2 turns)!", actor.Name),
		}
		table.insert(state.Log, logEntry)
	elseif chosenAbility.Type == "RoleSkill" and actor.Role == "Healer" then
		assert(target ~= nil, "Target required for heal")
		local healAmount = math.floor(actor.Stats.Attack * chosenAbility.PowerMultiplier)
		target.CurrentHp = math.min(target.MaxHp, target.CurrentHp + healAmount)

		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = "RoleSkill",
			TargetId = target.Id,
			Heal = healAmount,
			Message = string.format("%s healed %s for %d HP!", actor.Name, target.Name, healAmount),
		}
		table.insert(state.Log, logEntry)
	elseif chosenAbility.Type == "RoleSkill" and actor.Role == "Buffer" then
		-- Team attack surge (+35% ATK for 2 turns)
		for _, ally in actorTeam.Active do
			if ally.IsAlive then
				ally.AttackBuffTurns = 2
			end
		end
		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = "RoleSkill",
			TargetId = nil,
			Message = string.format(
				"%s activated Surge Boost (+35%% ATK, 2 turns) for all allies!",
				actor.Name
			),
		}
		table.insert(state.Log, logEntry)
	elseif chosenAbility.Type == "RoleSkill" and actor.Role == "Controller" then
		assert(target ~= nil, "Target required for controller skill")
		local finalDmg = math.max(1, math.floor(actor.Stats.Attack * chosenAbility.PowerMultiplier))
		target.CurrentHp = math.max(0, target.CurrentHp - finalDmg)
		if target.CurrentHp <= 0 then
			target.IsAlive = false
		else
			target.StunTurns = 1
		end

		local logEntry: CombatLogEntry = {
			Round = state.Round,
			ActorId = actor.Id,
			ActionType = "RoleSkill",
			TargetId = target.Id,
			Damage = finalDmg,
			Message = string.format(
				"%s used Neural Disrupt on %s for %d damage and STUNNED for 1 turn!",
				actor.Name,
				target.Name,
				finalDmg
			),
		}
		table.insert(state.Log, logEntry)
	end

	-- Check reserve deployment immediately upon casualty
	checkAndDeployReserve(state.PlayerTeam, state.Log, state.Round)
	checkAndDeployReserve(state.EnemyTeam, state.Log, state.Round)

	-- Check victory / defeat
	local status = updateCombatStatus(state)
	if status ~= "InProgress" then
		return true, nil
	end

	-- Advance turn in initiative queue
	advanceTurn(state, options)

	return true, nil
end

return table.freeze(CombatEngine)
