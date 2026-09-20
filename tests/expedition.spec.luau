--!strict

local ExpeditionGenerator = require("../src/server/Domain/ExpeditionGenerator")
local ExpeditionSession = require("../src/server/Domain/ExpeditionSession")
local RequestValidator = require("../src/server/Domain/RequestValidator")
local CombatTypes = require("../src/shared/Types/CombatTypes")

type SquadInput = CombatTypes.SquadInput

print("Running expedition.spec.luau")

-- 1. Test ExpeditionGenerator
local chain3 = ExpeditionGenerator.GenerateChain(3)
assert(#chain3 == 3, "Chain of 3 must have 3 rooms")
assert(chain3[1].Type == "Entrance" and not chain3[1].HasTerminal)
assert(chain3[2].Type == "Terminal" and chain3[2].HasTerminal)
assert(chain3[3].Type == "Boss" and chain3[3].HasTerminal)

local chain5 = ExpeditionGenerator.GenerateChain(5)
assert(#chain5 == 5, "Chain of 5 must have 5 rooms")
assert(chain5[3].HasTerminal, "Room 3 of 5 must have terminal")
assert(chain5[5].HasTerminal, "Room 5 of 5 must have terminal")

local okChain, _ = pcall(function()
	ExpeditionGenerator.GenerateChain(4)
end)
assert(not okChain, "Should reject room count other than 3 or 5")

-- 2. Test ExpeditionSession Lifecycle
local testSquad: SquadInput = {
	Active = {
		{
			Id = "hero_1",
			Name = "Hero Striker",
			Tier = 2,
			Role = "Striker",
			Genes = { { Element = "Plasma", Value = 150 } },
		},
		{
			Id = "hero_2",
			Name = "Hero Guardian",
			Tier = 2,
			Role = "Guardian",
			Genes = { { Element = "Biomass", Value = 100 } },
		},
	},
	Reserve = {
		{
			Id = "hero_res",
			Name = "Hero Reserve",
			Tier = 2,
			Role = "Striker",
			Genes = { { Element = "Electro", Value = 100 } },
		},
	},
}

local session = ExpeditionSession.new("exp_test_1", testSquad, 3)
assert(session.Status == "InCombat", "Session must start in InCombat")
assert(session.CurrentRoomIndex == 1, "Session must start in Room 1")
assert(session.PendingLoot.BioCoins == 0)
assert(session.SecuredLoot.BioCoins == 0)

-- Defeat room 1 enemy with high damage
assert(session.CurrentCombat ~= nil)
local currentActorId = session.CurrentCombat.CurrentTurnUnitId

---- Force hero turn to defeat enemy immediately
session.CurrentCombat.CurrentTurnUnitId = "hero_1"
for _, hero in session.CurrentCombat.PlayerTeam.Active do
	hero.StunTurns = 0
end
-- Lower enemy HP to 1
for _, enemy in session.CurrentCombat.EnemyTeam.Active do
	enemy.CurrentHp = 1
end

local stepOk, stepErr = session:StepCombatAction({
	ActorId = "hero_1",
	AbilityType = "Basic",
	TargetId = session.CurrentCombat.EnemyTeam.Active[1].Id,
})
assert(stepOk, "Step combat action must succeed: " .. tostring(stepErr))

-- Room 1 defeated: should gain Room 1 loot and advance to Room 2 (Terminal room)
assert(session.PendingLoot.BioCoins > 0, "Pending loot should receive room 1 reward")
assert(session.CurrentRoomIndex == 2, "Should auto-advance to Room 2")
assert(session.Status == "InCombat", "Room 2 has enemies, so status is InCombat")

-- Defeat all room 2 enemies
assert(session.CurrentCombat ~= nil)
while
	session.Status == "InCombat"
	and session.CurrentCombat
	and session.CurrentCombat.Status == "InProgress"
do
	local livingEnemy = nil
	for _, e in session.CurrentCombat.EnemyTeam.Active do
		if e.IsAlive and e.CurrentHp > 0 then
			livingEnemy = e
			break
		end
	end
	local attacker = nil
	for _, hero in session.CurrentCombat.PlayerTeam.Active do
		if hero.IsAlive and hero.CurrentHp > 0 then
			attacker = hero
			break
		end
	end
	assert(attacker, "Should have a living hero")
	session.CurrentCombat.CurrentTurnUnitId = attacker.Id
	attacker.StunTurns = 0
	attacker.CurrentHp = attacker.MaxHp
	livingEnemy.CurrentHp = 1
	local sOk, sErr = session:StepCombatAction({
		ActorId = attacker.Id,
		AbilityType = "Basic",
		TargetId = livingEnemy.Id,
	})
	assert(sOk, "Hero attack must succeed: " .. tostring(sErr))
end

-- Room 2 has a terminal, so status should now be AtTerminal!
assert(session.Status == "AtTerminal", "Status must become AtTerminal after room 2 victory")
local pendingBeforeSecure = session.PendingLoot.BioCoins
assert(pendingBeforeSecure > 0, "Pending loot must be > 0")
assert(session.SecuredLoot.BioCoins == 0, "Secured loot before secure must be 0")

-- Secure loot at terminal
local secOk = session:SecureLoot()
assert(secOk, "Secure loot at terminal must succeed")
assert(session.SecuredLoot.BioCoins == pendingBeforeSecure, "Secured loot received pending loot")
assert(session.PendingLoot.BioCoins == 0, "Pending loot must be cleared after securing")

-- Evacuate voluntarily from terminal
local evacOk, claimedLoot, evacErr = session:Evacuate()
assert(evacOk and claimedLoot ~= nil, "Evacuation must succeed: " .. tostring(evacErr))
assert(session.Status == "Completed", "Session must be Completed after evacuation")
assert(claimedLoot.BioCoins == pendingBeforeSecure)

-- Re-evacuation must be rejected when Completed
local reEvacOk, _, reEvacErr = session:Evacuate()
assert(not reEvacOk, "Re-evacuation when Completed must be disallowed")
assert(reEvacErr == "CANNOT_EVACUATE")

-- TakeUncreditedLoot test
local uncredited = session:TakeUncreditedLoot()
assert(uncredited.BioCoins == pendingBeforeSecure, "First TakeUncreditedLoot must return full secured loot")
local emptyUncredited = session:TakeUncreditedLoot()
assert(emptyUncredited.BioCoins == 0, "Second TakeUncreditedLoot must return 0 delta")

-- 3. Test Defeat Scenario (Pending loot lost, Secured loot preserved, anti-skip)
local sessionFail = ExpeditionSession.new("exp_test_fail", testSquad, 3)
sessionFail.PendingLoot.BioCoins = 75
sessionFail.SecuredLoot.BioCoins = 120

-- In combat: ProceedToNextRoom must be rejected
assert(sessionFail.Status == "InCombat", "Session must be InCombat")
local cannotSkipOk, cannotSkipErr = sessionFail:ProceedToNextRoom()
assert(not cannotSkipOk, "Cannot skip combat via ProceedToNextRoom")
assert(cannotSkipErr == "CANNOT_PROCEED")

-- Simulate natural defeat through StepCombatAction
assert(sessionFail.CurrentCombat ~= nil)
sessionFail.CurrentCombat.PlayerTeam.Active[1].CurrentHp = 0
sessionFail.CurrentCombat.PlayerTeam.Active[1].IsAlive = false
sessionFail.CurrentCombat.PlayerTeam.Active[2].CurrentHp = 1
sessionFail.CurrentCombat.PlayerTeam.Reserve = {}

local enemyUnit = sessionFail.CurrentCombat.EnemyTeam.Active[1]
sessionFail.CurrentCombat.CurrentTurnUnitId = enemyUnit.Id
local failStepOk, failStepErr = sessionFail:StepCombatAction({
	ActorId = enemyUnit.Id,
	AbilityType = "Basic",
	TargetId = sessionFail.CurrentCombat.PlayerTeam.Active[2].Id,
})
assert(failStepOk, "Fatal enemy turn must succeed: " .. tostring(failStepErr))

-- Naturally transitioned to Defeat and Failed status
assert(sessionFail.CurrentCombat.Status == "Defeat", "Combat must end in Defeat")
assert(sessionFail.Status == "Failed", "Session status must naturally transition to Failed")
assert(sessionFail.PendingLoot.BioCoins == 0, "Pending loot must be wiped on failure")
assert(sessionFail.SecuredLoot.BioCoins == 120, "Secured loot must remain intact on failure")

-- 4. Test RequestValidator for v2 actions
assert(RequestValidator.isValid("StartExpedition", {
	RoomCount = 3,
	ActiveIds = { "m1", "m2" },
	ReserveIds = { "m3" },
}))
assert(not RequestValidator.isValid("StartExpedition", {
	RoomCount = 3,
	ActiveIds = { "m1", "m1" },
}), "Duplicate ActiveIds must be rejected")
assert(not RequestValidator.isValid("StartExpedition", {
	RoomCount = 3,
	ActiveIds = { "m1" },
	ReserveIds = { "m1" },
}), "Overlap between ActiveIds and ReserveIds must be rejected")
assert(RequestValidator.isValid("StartExpedition", {
	RoomCount = 5,
	ActiveIds = { "m1" },
}))
assert(not RequestValidator.isValid("StartExpedition", {
	RoomCount = 4, -- Only 3 or 5 allowed
	ActiveIds = { "m1" },
}))
assert(not RequestValidator.isValid("StartExpedition", {
	RoomCount = 3,
	ActiveIds = {}, -- Must have at least 1 active
}))

assert(RequestValidator.isValid("SelectCombatAction", {
	AbilityType = "Basic",
	TargetId = "enemy_1",
}))
assert(RequestValidator.isValid("SelectCombatAction", {
	AbilityType = "RoleSkill",
}))
assert(not RequestValidator.isValid("SelectCombatAction", {
	AbilityType = "CheatSkill",
}))

assert(RequestValidator.isValid("SecureLoot", nil))
assert(RequestValidator.isValid("SecureLoot", {}))
assert(RequestValidator.isValid("Evacuate", nil))
assert(RequestValidator.isValid("Evacuate", {}))

assert(RequestValidator.isValid("BreedMutants", {
	FirstId = "blob_1",
	SecondId = "blob_2",
}))
assert(not RequestValidator.isValid("BreedMutants", {
	FirstId = "blob_1",
}))

print(
	"PASS expedition: generator, session lifecycle, terminals, wipe on defeat, and v2 request validation verified"
)
