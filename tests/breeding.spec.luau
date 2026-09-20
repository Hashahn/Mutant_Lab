--!strict

local BreedingService = require("../src/shared/Domain/BreedingService")
local RestCooldownService = require("../src/shared/Domain/RestCooldownService")
local MutantTypes = require("../src/shared/Types/MutantTypes")

type Mutant = MutantTypes.Mutant

print("Running breeding.spec.luau")

-- 1. Test Gene Slot Limits
assert(BreedingService.GetMaxGeneSlots(1) == 3, "Tier 1 must have 3 slots")
assert(BreedingService.GetMaxGeneSlots(2) == 4, "Tier 2 must have 4 slots")
assert(BreedingService.GetMaxGeneSlots(3) == 5, "Tier 3 must have 5 slots")

-- 2. Test Survival Odds
local odds1_1A, odds1_1B = BreedingService.GetSurvivalOdds(1, 1)
assert(odds1_1A == 0.5 and odds1_1B == 0.5, "Equal tier must have 50/50 odds")

local odds2_2A, odds2_2B = BreedingService.GetSurvivalOdds(2, 2)
assert(odds2_2A == 0.5 and odds2_2B == 0.5, "Tier 2 equal must have 50/50 odds")

local odds2_1A, odds2_1B = BreedingService.GetSurvivalOdds(2, 1)
assert(odds2_1A == 0.8 and odds2_1B == 0.2, "T2 vs T1 must be 80/20")

local odds1_2A, odds1_2B = BreedingService.GetSurvivalOdds(1, 2)
assert(odds1_2A == 0.2 and odds1_2B == 0.8, "T1 vs T2 must be 20/80")

local odds3_2A, odds3_2B = BreedingService.GetSurvivalOdds(3, 2)
assert(odds3_2A == 0.75 and odds3_2B == 0.25, "T3 vs T2 must be 75/25")

local odds3_1A, odds3_1B = BreedingService.GetSurvivalOdds(3, 1)
assert(odds3_1A == 0.95 and odds3_1B == 0.05, "T3 vs T1 must be 95/5")

-- 3. Self breeding rejection
local mutantSelf: Mutant = {
	Id = "m_self",
	Type = "Blob",
	Tier = 1,
	Level = 1,
}
local sameOk, _, sameErr = BreedingService.Breed(mutantSelf, mutantSelf)
assert(not sameOk and sameErr == "CANNOT_BREED_SAME_MUTANT")

-- 4. Gene inheritance & existing gene enhancement
local mutantA: Mutant = {
	Id = "m_survivor",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = {
		{ Element = "Plasma", Value = 50 },
	},
}

local mutantB: Mutant = {
	Id = "m_victim",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = {
		{ Element = "Plasma", Value = 40 },
	},
}

-- Force survivor to win (roll = 0.1 < 0.5), transfer ratio = 0.5 -> 40 * 0.5 = 20
local bOk, bRes = BreedingService.Breed(mutantA, mutantB, {
	Rng = function()
		return 0.1
	end,
	TransferRatio = 0.5,
})
assert(bOk and bRes ~= nil)
assert(bRes.Survivor.Id == "m_survivor", "Mutant A should be survivor")
assert(bRes.ConsumedId == "m_victim", "Mutant B should be consumed")
assert(bRes.Survivor.Tier == 1, "Breeding must NOT increase tier")
assert(bRes.Survivor.Genes ~= nil)
assert(#bRes.Survivor.Genes == 1, "Existing Plasma gene was enhanced, not duplicated")
assert(bRes.Survivor.Genes[1].Value == 70, "Plasma gene should be 50 + 20 = 70")

-- 5. New gene slot addition
local mutantC: Mutant = {
	Id = "m_donor_cryo",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = {
		{ Element = "Cryo", Value = 60 },
	},
}
local cOk, cRes = BreedingService.Breed(bRes.Survivor, mutantC, {
	Rng = function()
		return 0.1
	end,
	TransferRatio = 0.5,
})
assert(cOk and cRes ~= nil)
assert(#cRes.Survivor.Genes == 2, "Survivor now has 2 genes (Plasma and Cryo)")
assert(cRes.InheritedGene ~= nil and cRes.InheritedGene.Element == "Cryo")
assert(cRes.InheritedGene.Value == 30)

-- 6. Gene displacement when slots are full
-- Tier 1 has 3 slots max. Let's fill slot 3 with a weak Biomass gene (Value = 5)
local filledT1: Mutant = {
	Id = "m_full",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = {
		{ Element = "Plasma", Value = 70 },
		{ Element = "Cryo", Value = 30 },
		{ Element = "Biomass", Value = 5 }, -- Weakest gene
	},
}
local donorElectro: Mutant = {
	Id = "m_donor_electro",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = {
		{ Element = "Electro", Value = 80 }, -- Transfer 0.5 * 80 = 40 (> 5)
	},
}
local dOk, dRes = BreedingService.Breed(filledT1, donorElectro, {
	Rng = function()
		return 0.1
	end,
	TransferRatio = 0.5,
})
assert(dOk and dRes ~= nil)
assert(#dRes.Survivor.Genes == 3, "Slots count remains at max 3")
assert(dRes.DisplacedGene ~= nil, "Lowest gene must be displaced")
assert(dRes.DisplacedGene.Element == "Biomass" and dRes.DisplacedGene.Value == 5)
-- Verify Electro replaced Biomass
local hasElectro = false
for _, g in dRes.Survivor.Genes do
	if g.Element == "Electro" and g.Value == 40 then
		hasElectro = true
	end
end
assert(hasElectro, "Electro must have replaced Biomass")

-- 7. RestCooldownService tests
local now = 1000
local restingMutant = RestCooldownService.StartRest(filledT1, now)
assert(RestCooldownService.IsOnRest(restingMutant, now) == true, "Must be on rest at start")
assert(RestCooldownService.IsOnRest(restingMutant, now + 60) == true, "Must be on rest after 60s")
assert(RestCooldownService.GetRemainingRest(restingMutant, now + 60) == 60)
assert(RestCooldownService.IsOnRest(restingMutant, now + 121) == false, "Must not be on rest after 121s")

-- Complete rest with guaranteed bonus mutation (Rng = 0.0)
local completedMutant, bonus = RestCooldownService.CompleteRest(restingMutant, now + 120, function()
	return 0.0
end)
assert(completedMutant.RestUntil == nil, "RestUntil must be cleared")
assert(bonus ~= nil, "Bonus mutation should trigger with Rng = 0.0")
assert(bonus.ValueAdded >= 5 and bonus.ValueAdded <= 15)

-- 8. Gene Clamping at 100
local nearCapMutant = {
	Id = "near_cap",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = { { Element = "Biomass", Value = 95 } },
}
local donorMutant = {
	Id = "donor",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = { { Element = "Biomass", Value = 50 } },
}
local capOk, capRes = BreedingService.Breed(nearCapMutant, donorMutant, {
	Rng = function()
		return 0.0
	end, -- nearCapMutant survives, picks Biomass
})
assert(capOk and capRes ~= nil)
assert(capRes.Survivor.Genes[1].Value == 100, "Gene value must be clamped to 100")

-- RestCooldownService gene cap
local capRestMutant = {
	Id = "cap_rest",
	Type = "Blob",
	Tier = 1,
	Level = 1,
	Genes = { { Element = "Plasma", Value = 98 } },
}
local capRestCompleted, _ = RestCooldownService.CompleteRest(capRestMutant, now, function()
	return 0.0
end)
assert(capRestCompleted.Genes[1].Value == 100, "Rest bonus gene value must be clamped to 100")

-- 9. GameState Profile Validation after Breeding Free Blobs
local GameState = require("../src/server/Domain/GameState")
local GameConfig = require("../src/shared/Config/GameConfig")
local MutantConfig = require("../src/shared/Config/MutantConfig")

local bredProfile = GameState.newProfile(GameConfig)
bredProfile.Tutorial.Started = true
bredProfile.Tutorial.FirstBlobCreated = true
bredProfile.Tutorial.FreeBlobsClaimed = 2
-- Player claimed 2 free Blobs and bred them together, leaving 1 Blob and 1 BreedingConsumedUnits
bredProfile.Mutants = {
	{ Id = "survivor_blob", Type = "Blob", Tier = 1, Level = 1 },
}
bredProfile.BreedingConsumedUnits = 1
assert(
	GameState.validateProfile(bredProfile, GameConfig, MutantConfig) == true,
	"Profile with BreedingConsumedUnits must validate successfully"
)

print("PASS breeding: survival odds, inheritance, displacement, tier invariants, and rest cooldowns verified")
