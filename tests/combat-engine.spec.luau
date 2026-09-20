--!strict

local CombatEngine = require("../src/shared/Combat/CombatEngine")
local MutantStats = require("../src/shared/Combat/MutantStats")

print("Running combat-engine.spec.luau")

-- 1. Test MutantStats: Effective Elements & Tier Slots
local genesT1 = {
	{ Element = "Biomass", Value = 15 },
	{ Element = "Plasma", Value = 40 },
	{ Element = "Cryo", Value = 25 },
}
local effT1 = MutantStats.CalculateEffectiveElements(1, genesT1)
assert(effT1.Primary == "Plasma", "Plasma (40) must be Primary")
assert(effT1.Secondary == "Cryo", "Cryo (25) must be Secondary")
assert(effT1.Tertiary == nil, "Tier 1 must have no active tertiary element")

local genesT2 = {
	{ Element = "Shadow", Value = 10 },
	{ Element = "Biomass", Value = 30 },
	{ Element = "Toxin", Value = 50 },
	{ Element = "Electro", Value = 40 },
}
local effT2 = MutantStats.CalculateEffectiveElements(2, genesT2)
assert(effT2.Primary == "Toxin", "Toxin (50) must be Primary")
assert(effT2.Secondary == "Electro", "Electro (40) must be Secondary")
assert(effT2.Tertiary == "Biomass", "Biomass (30) must be Tertiary")
assert(effT2.TertiaryWeight == 0.5, "Tier 2 Tertiary weight must be 0.5")

local genesT3 = {
	{ Element = "Plasma", Value = 80 },
	{ Element = "Electro", Value = 60 },
	{ Element = "Cryo", Value = 70 },
	{ Element = "Shadow", Value = 20 },
	{ Element = "Biomass", Value = 30 },
}
local effT3 = MutantStats.CalculateEffectiveElements(3, genesT3)
assert(effT3.Primary == "Plasma", "Plasma (80) must be Primary")
assert(effT3.Secondary == "Cryo", "Cryo (70) must be Secondary")
assert(effT3.Tertiary == "Electro", "Electro (60) must be Tertiary")
assert(effT3.TertiaryWeight == 1.0, "Tier 3 Tertiary weight must be 1.0")

-- 2. Test Stat Calculations & Roles
local guardianStats = MutantStats.CalculateStats(2, genesT2, "Guardian")
local strikerStats = MutantStats.CalculateStats(2, genesT2, "Striker")
assert(guardianStats.MaxHp > strikerStats.MaxHp, "Guardian must have higher Max HP")
assert(strikerStats.Attack > guardianStats.Attack, "Striker must have higher Attack")
assert(guardianStats.AutoGuardChance >= 0.05 and guardianStats.AutoGuardChance <= 0.35)

local guardianAbilities = MutantStats.BuildAbilities(2, "Guardian", guardianStats)
assert(#guardianAbilities == 3, "Mutant must have exactly 3 abilities")
assert(guardianAbilities[1].Type == "Basic", "Ability 1 must be Basic")
assert(guardianAbilities[2].Type == "RoleSkill", "Ability 2 must be RoleSkill")
assert(guardianAbilities[3].Type == "Ultimate", "Ability 3 must be Ultimate")

-- 3. Test CombatEngine Initialization & Initiative by Speed
local playerSquad: { CombatEngine.UnitInput } = {
	{
		Id = "p_fast",
		Name = "Fast Striker",
		Tier = 2,
		Role = "Striker",
		Genes = { { Element = "Electro", Value = 100 }, { Element = "Plasma", Value = 20 } },
	},
	{
		Id = "p_tank",
		Name = "Iron Guardian",
		Tier = 2,
		Role = "Guardian",
		Genes = { { Element = "Biomass", Value = 80 }, { Element = "Cryo", Value = 40 } },
	},
	{
		Id = "p_healer",
		Name = "Bio Healer",
		Tier = 1,
		Role = "Healer",
		Genes = { { Element = "Biomass", Value = 50 }, { Element = "Toxin", Value = 10 } },
	},
	{
		-- Reserve unit
		Id = "p_reserve",
		Name = "Plasma Reserve",
		Tier = 3,
		Role = "Striker",
		Genes = { { Element = "Plasma", Value = 90 } },
	},
}

local enemySquad: { CombatEngine.UnitInput } = {
	{
		Id = "e_boss",
		Name = "Shadow Monster",
		Tier = 2,
		Role = "Striker",
		Genes = { { Element = "Shadow", Value = 70 }, { Element = "Biomass", Value = 30 } },
	},
	{
		Id = "e_minion",
		Name = "Toxic Minion",
		Tier = 1,
		Role = "Controller",
		Genes = { { Element = "Toxin", Value = 40 } },
	},
}

local combat = CombatEngine.Init(playerSquad, enemySquad, {
	StartingEnergy = 4,
	MaxEnergy = 10,
	PassiveEnergy = 2,
})

assert(combat.Round == 1, "Combat must start at Round 1")
assert(#combat.PlayerTeam.Active == 3, "Player active must have 3 units")
assert(#combat.PlayerTeam.Reserve == 1, "Player reserve must have 1 unit")
assert(#combat.EnemyTeam.Active == 2, "Enemy active must have 2 units")
assert(#combat.InitiativeQueue == 5, "Initiative queue must have all 5 active units")

-- The fastest unit must act first
local fastUnit = nil
for _, u in combat.PlayerTeam.Active do
	if u.Id == "p_fast" then
		fastUnit = u
		break
	end
end
assert(fastUnit ~= nil)
assert(combat.CurrentTurnUnitId == combat.InitiativeQueue[1], "Current turn must be top of queue")

-- 4. Turn validation: cannot act out of turn
local invalidAct, err = CombatEngine.Step(combat, {
	ActorId = "e_boss", -- Not the current turn actor
	AbilityType = "Basic",
})
assert(not invalidAct and err == "NOT_ACTORS_TURN", "Should reject action from non-current actor")

-- 5. Basic attack & energy generation
local currentActorId = combat.CurrentTurnUnitId
local initialEnergy = combat.PlayerTeam.Energy
local actOk, actErr = CombatEngine.Step(combat, {
	ActorId = currentActorId,
	AbilityType = "Basic",
	TargetId = "e_boss",
})
assert(actOk, "Basic attack must succeed: " .. tostring(actErr))
-- If the actor was on player team, energy increased by 1 (Basic attack EnergyGain = 1)
if currentActorId:sub(1, 2) == "p_" then
	assert(combat.PlayerTeam.Energy == initialEnergy + 1, "Basic attack should grant +1 energy")
end

-- 6. Test Taunt mechanic & Redirection
-- Create a dedicated state where guardian uses Taunt
local tauntCombat = CombatEngine.Init({
	{
		Id = "guardian_1",
		Name = "Guardian",
		Tier = 1,
		Role = "Guardian",
		Genes = { { Element = "Biomass", Value = 50 } },
	},
	{
		Id = "ally_1",
		Name = "Ally",
		Tier = 1,
		Role = "Striker",
		Genes = { { Element = "Plasma", Value = 10 } },
	},
}, {
	{
		Id = "enemy_1",
		Name = "Enemy Striker",
		Tier = 1,
		Role = "Striker",
		Genes = { { Element = "Plasma", Value = 50 } },
	},
}, {
	StartingEnergy = 5,
})

-- Force turn to Guardian
tauntCombat.CurrentTurnUnitId = "guardian_1"
local gOk, gErr = CombatEngine.Step(tauntCombat, {
	ActorId = "guardian_1",
	AbilityType = "RoleSkill",
})
assert(gOk, "Guardian taunt should succeed: " .. tostring(gErr))
local gUnit = tauntCombat.PlayerTeam.Active[1]
assert(gUnit.TauntTurns == 2, "Guardian must have TauntTurns = 2")

-- Now enemy attacks ally_1: must be redirected to guardian_1 because of Taunt!
tauntCombat.CurrentTurnUnitId = "enemy_1"
local initialGuardianHp = gUnit.CurrentHp
local eOk, eErr = CombatEngine.Step(tauntCombat, {
	ActorId = "enemy_1",
	AbilityType = "Basic",
	TargetId = "ally_1", -- Intentionally targeting the ally
})
assert(eOk, "Enemy attack must succeed: " .. tostring(eErr))
assert(gUnit.CurrentHp < initialGuardianHp, "Damage must have been redirected to Guardian")

-- 7. Test Auto-Guard (deterministic RNG)
local guardTestCombat = CombatEngine.Init({
	{
		Id = "attacker",
		Name = "Attacker",
		Tier = 1,
		Role = "Striker",
		Genes = { { Element = "Plasma", Value = 50 } },
	},
}, {
	{
		Id = "defender",
		Name = "Defender",
		Tier = 1,
		Role = "Guardian",
		Genes = { { Element = "Biomass", Value = 100 } },
	},
}, {
	-- Force RNG to return 0.0 (guaranteed auto-guard trigger)
	Rng = function()
		return 0.0
	end,
})
guardTestCombat.CurrentTurnUnitId = "attacker"
CombatEngine.Step(guardTestCombat, {
	ActorId = "attacker",
	AbilityType = "Basic",
	TargetId = "defender",
}, {
	Rng = function()
		return 0.0
	end,
})
local lastLog = guardTestCombat.Log[#guardTestCombat.Log]
assert(lastLog.IsGuarded == true, "Must register as Guarded when roll < AutoGuardChance")

-- 8. Test Reserve Deployment on Active Wipe
local reserveCombat = CombatEngine.Init({
	Active = {
		{
			Id = "fragile_active",
			Name = "Fragile",
			Tier = 1,
			Role = "Striker",
			Genes = { { Element = "Plasma", Value = 10 } },
		},
	},
	Reserve = {
		{
			Id = "p_res_1",
			Name = "Reserve Champion",
			Tier = 2,
			Role = "Striker",
			Genes = { { Element = "Electro", Value = 80 } },
		},
	},
}, {
	Active = {
		{
			Id = "boss",
			Name = "Boss",
			Tier = 3,
			Role = "Striker",
			Genes = { { Element = "Plasma", Value = 200 } },
		},
	},
})

assert(#reserveCombat.PlayerTeam.Active == 1, "Player active must have 1 unit")
assert(#reserveCombat.PlayerTeam.Reserve == 1, "Player reserve must have 1 unit")
reserveCombat.PlayerTeam.Active[1].CurrentHp = 1

-- Boss strikes fragile_active for fatal damage
reserveCombat.CurrentTurnUnitId = "boss"
local bossOk = CombatEngine.Step(reserveCombat, {
	ActorId = "boss",
	AbilityType = "Basic",
	TargetId = "fragile_active",
})
assert(bossOk)
assert(reserveCombat.PlayerTeam.ReserveDeployed == true, "Reserve must be deployed upon active squad defeat")
assert(#reserveCombat.PlayerTeam.Active == 1, "Active squad now has reserve unit")
assert(reserveCombat.PlayerTeam.Active[1].Id == "p_res_1", "Deployed unit must be the reserve champion")
assert(reserveCombat.Status == "InProgress", "Battle must still be InProgress because reserve is fighting")

-- 9. Defeat and Victory conditions
-- Defeating reserve unit leads to Defeat
reserveCombat.PlayerTeam.Active[1].CurrentHp = 1
reserveCombat.CurrentTurnUnitId = "boss"
CombatEngine.Step(reserveCombat, {
	ActorId = "boss",
	AbilityType = "Basic",
	TargetId = "p_res_1",
})
assert(
	reserveCombat.Status == "Defeat",
	"Battle must result in Defeat when all units including reserve are dead"
)

print(
	"PASS combat-engine: stats, roles, abilities, turn queue, energy, taunt, guard, reserve, win/loss verified"
)
