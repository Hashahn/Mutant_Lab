--!strict

local ElementMatrix = require("../src/shared/Combat/ElementMatrix")
local RestCooldownService = require("../src/shared/Domain/RestCooldownService")
local CombatTypes = require("../src/shared/Types/CombatTypes")
local MutantTypes = require("../src/shared/Types/MutantTypes")

print("Running client-presentation.spec.luau")

-- 1. Test Element Advantage Presentation Indicators
local function getMatchupIndicator(
	attackerElem: CombatTypes.Element,
	defenderElem: CombatTypes.Element,
	attackerVoidCore: boolean?,
	defenderVoidCore: boolean?
): string
	local mult = ElementMatrix.GetMultiplier(attackerElem, defenderElem, attackerVoidCore, defenderVoidCore)
	if mult > 1.0 then
		return string.format("⚔ %.1fx WEAK", mult)
	elseif mult < 1.0 then
		return string.format("🛡 %.2fx RESIST", mult)
	else
		return "⚖ 1.0x NEUTRAL"
	end
end

assert(getMatchupIndicator("Plasma", "Cryo") == "⚔ 1.5x WEAK", "Plasma vs Cryo must indicate WEAK")
assert(getMatchupIndicator("Cryo", "Plasma") == "🛡 0.75x RESIST", "Cryo vs Plasma must indicate RESIST")
assert(
	getMatchupIndicator("Plasma", "Plasma") == "⚖ 1.0x NEUTRAL",
	"Plasma vs Plasma must indicate NEUTRAL"
)
assert(
	getMatchupIndicator("Plasma", "Cryo", true, false) == "⚖ 1.0x NEUTRAL",
	"Void Core must indicate NEUTRAL"
)

-- 2. Test Energy Affordability Rules
local function canAffordAbility(currentEnergy: number, abilityCost: number): boolean
	return currentEnergy >= abilityCost
end

assert(canAffordAbility(0, 0) == true, "Basic ability (cost 0) must always be affordable")
assert(canAffordAbility(1, 2) == false, "RoleSkill (cost 2) cannot be cast with 1 energy")
assert(canAffordAbility(2, 2) == true, "RoleSkill (cost 2) can be cast with 2 energy")
assert(canAffordAbility(4, 5) == false, "Ultimate (cost 5) cannot be cast with 4 energy")
assert(canAffordAbility(5, 5) == true, "Ultimate (cost 5) can be cast with 5 energy")

-- 3. Test Rest Cooldown Filtering for Squad Selection
local now = 1000
local restingMutant: MutantTypes.Mutant = {
	Id = "m_resting",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	RestUntil = now + 60,
}

local readyMutant: MutantTypes.Mutant = {
	Id = "m_ready",
	Type = "ToxicBlob",
	Tier = 2,
	Level = 1,
	RestUntil = nil,
}

local expiredRestMutant: MutantTypes.Mutant = {
	Id = "m_expired",
	Type = "PlasmaBlob",
	Tier = 3,
	Level = 1,
	RestUntil = now - 10,
}

assert(RestCooldownService.IsOnRest(restingMutant, now) == true, "Resting mutant must be flagged as on rest")
assert(RestCooldownService.IsOnRest(readyMutant, now) == false, "Ready mutant must not be flagged as on rest")
assert(RestCooldownService.IsOnRest(expiredRestMutant, now) == false, "Expired rest mutant must be ready")

-- 4. Test Squad Slot Invariants (3 active + up to 3 reserve)
local activeSlots = {}
local reserveSlots = {}
local function addToSquad(mutantId: string): boolean
	if #activeSlots < 3 then
		table.insert(activeSlots, mutantId)
		return true
	elseif #reserveSlots < 3 then
		table.insert(reserveSlots, mutantId)
		return true
	end
	return false
end

for i = 1, 3 do
	assert(addToSquad("active_" .. i) == true, "Should fill active slots 1..3")
end
assert(#activeSlots == 3)

for i = 1, 3 do
	assert(addToSquad("reserve_" .. i) == true, "Should fill reserve slots 1..3")
end
assert(#reserveSlots == 3)

assert(addToSquad("overflow_7") == false, "7th unit must be rejected (max 6)")

print(
	"PASS client-presentation: matchup indicators, energy checks, rest filtering, and squad constraints verified"
)
