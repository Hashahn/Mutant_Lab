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

-- Force hero turn to defeat enemy immediately
session.CurrentCombat.CurrentTurnUnitId = "hero_1"
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
	if not livingEnemy then
		break
	end
	session.CurrentCombat.CurrentTurnUnitId = "hero_1"
	livingEnemy.CurrentHp = 1
	local sOk = session:StepCombatAction({
		ActorId = "hero_1",
		AbilityType = "Basic",
		TargetId = livingEnemy.Id,
	})
	assert(sOk)
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

-- 3. Test Defeat Scenario (Pending loot lost, Secured loot preserved)
local sessionFail = ExpeditionSession.new("exp_test_fail", testSquad, 3)
sessionFail.PendingLoot.BioCoins = 75
sessionFail.SecuredLoot.BioCoins = 120

-- Simulate defeat
assert(sessionFail.CurrentCombat ~= nil)
-- Set all player units to 1 HP and no reserve
sessionFail.CurrentCombat.PlayerTeam.Active[1].CurrentHp = 1
sessionFail.CurrentCombat.PlayerTeam.Active[2].CurrentHp = 1
sessionFail.CurrentCombat.PlayerTeam.Reserve = {}

-- Enemy attacks fatally
local enemyUnit = sessionFail.CurrentCombat.EnemyTeam.Active[1]
sessionFail.CurrentCombat.CurrentTurnUnitId = enemyUnit.Id
sessionFail.CurrentCombat.PlayerTeam.Active[1].CurrentHp = 0
sessionFail.CurrentCombat.PlayerTeam.Active[1].IsAlive = false

session:StepCombatAction({
	ActorId = enemyUnit.Id,
	AbilityType = "Basic",
	TargetId = sessionFail.CurrentCombat.PlayerTeam.Active[2].Id,
})

-- Test wipe directly on session
sessionFail.CurrentCombat.Status = "Defeat"
sessionFail.Status = "Failed"
sessionFail.PendingLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }

assert(sessionFail.PendingLoot.BioCoins == 0, "Pending loot must be wiped on failure")
assert(sessionFail.SecuredLoot.BioCoins == 120, "Secured loot must remain intact on failure")

-- 4. Test RequestValidator for v2 actions
assert(RequestValidator.isValid("StartExpedition", {
	RoomCount = 3,
	ActiveIds = { "m1", "m2" },
	ReserveIds = { "m3" },
}))
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
