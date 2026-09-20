--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox
	then require(script.Parent.Parent.Types.CombatTypes)
	else require("../Types/CombatTypes")
local MutantTypes = if isRoblox
	then require(script.Parent.Parent.Types.MutantTypes)
	else require("../Types/MutantTypes")

type Element = CombatTypes.Element
type Gene = CombatTypes.Gene
type Mutant = MutantTypes.Mutant

local BreedingService = {}

local MAX_SLOTS_BY_TIER: { [number]: number } = {
	[1] = 3,
	[2] = 4,
	[3] = 5,
}

export type BreedingOdds = {
	OddsA: number,
	OddsB: number,
}

export type BreedingResult = {
	Success: boolean,
	Survivor: Mutant,
	ConsumedId: string,
	InheritedGene: Gene?,
	DisplacedGene: Gene?,
	SurvivorWonOdds: number,
	Log: string,
}

export type BreedingOptions = {
	Rng: (() -> number)?,
	TransferRatio: number?,
}

function BreedingService.GetMaxGeneSlots(tier: number): number
	return MAX_SLOTS_BY_TIER[tier] or 3
end

function BreedingService.GetSurvivalOdds(tierA: number, tierB: number): (number, number)
	if tierA == tierB then
		return 0.50, 0.50
	elseif tierA == 2 and tierB == 1 then
		return 0.80, 0.20
	elseif tierA == 1 and tierB == 2 then
		return 0.20, 0.80
	elseif tierA == 3 and tierB == 2 then
		return 0.75, 0.25
	elseif tierA == 2 and tierB == 3 then
		return 0.25, 0.75
	elseif tierA == 3 and tierB == 1 then
		return 0.95, 0.05
	elseif tierA == 1 and tierB == 3 then
		return 0.05, 0.95
	else
		-- General fallback if higher tiers are added in the future
		local diff = tierA - tierB
		if diff > 0 then
			local odds = math.clamp(0.50 + diff * 0.25, 0.50, 0.95)
			return odds, 1.0 - odds
		else
			local odds = math.clamp(0.50 + math.abs(diff) * 0.25, 0.50, 0.95)
			return 1.0 - odds, odds
		end
	end
end

local function cloneGenes(genes: { Gene }?): { Gene }
	local res: { Gene } = {}
	if genes then
		for _, g in genes do
			table.insert(res, { Element = g.Element, Value = g.Value })
		end
	end
	return res
end

function BreedingService.Breed(
	mutantA: Mutant,
	mutantB: Mutant,
	options: BreedingOptions?
): (boolean, BreedingResult?, string?)
	if mutantA.Id == mutantB.Id then
		return false, nil, "CANNOT_BREED_SAME_MUTANT"
	end

	local rng = if options and options.Rng then options.Rng else math.random
	local transferRatio = if options and options.TransferRatio then options.TransferRatio else 0.40

	local oddsA, oddsB = BreedingService.GetSurvivalOdds(mutantA.Tier, mutantB.Tier)
	local roll = rng()

	local survivorOriginal: Mutant
	local victimOriginal: Mutant
	local survivorOdds: number

	if roll < oddsA then
		survivorOriginal = mutantA
		victimOriginal = mutantB
		survivorOdds = oddsA
	else
		survivorOriginal = mutantB
		victimOriginal = mutantA
		survivorOdds = oddsB
	end

	-- Clone survivor to preserve immutability
	local survivorGenes = cloneGenes(survivorOriginal.Genes)
	local victimGenes = cloneGenes(victimOriginal.Genes)

	local inheritedGene: Gene? = nil
	local displacedGene: Gene? = nil

	if #victimGenes > 0 then
		-- Select random gene from victim
		local geneIdx = math.clamp(math.floor(rng() * #victimGenes) + 1, 1, #victimGenes)
		local selectedVictimGene = victimGenes[geneIdx]

		local transferValue = math.max(1, math.floor(selectedVictimGene.Value * transferRatio))
		inheritedGene = {
			Element = selectedVictimGene.Element,
			Value = transferValue,
		}

		-- Check if survivor already has this element
		local existingGene: Gene? = nil
		for _, g in survivorGenes do
			if g.Element == selectedVictimGene.Element then
				existingGene = g
				break
			end
		end

		if existingGene then
			-- Enhance existing gene
			existingGene.Value += transferValue
		else
			-- New gene to be added
			local maxSlots = BreedingService.GetMaxGeneSlots(survivorOriginal.Tier)
			if #survivorGenes < maxSlots then
				table.insert(survivorGenes, {
					Element = selectedVictimGene.Element,
					Value = transferValue,
				})
			else
				-- Find gene with lowest value to displace
				local lowestIndex = 1
				local lowestVal = survivorGenes[1].Value
				for i = 2, #survivorGenes do
					if survivorGenes[i].Value < lowestVal then
						lowestVal = survivorGenes[i].Value
						lowestIndex = i
					end
				end

				if transferValue > lowestVal then
					displacedGene = survivorGenes[lowestIndex]
					survivorGenes[lowestIndex] = {
						Element = selectedVictimGene.Element,
						Value = transferValue,
					}
				end
			end
		end
	end

	local updatedSurvivor: Mutant = {
		Id = survivorOriginal.Id,
		Type = survivorOriginal.Type,
		Tier = survivorOriginal.Tier, -- Tier NEVER increases through breeding!
		Level = survivorOriginal.Level,
		Role = survivorOriginal.Role,
		Genes = survivorGenes,
		RestUntil = survivorOriginal.RestUntil,
	}

	local logMsg = string.format(
		"Breeding complete: %s (Tier %d) survived against %s (Tier %d) with %.0f%% survival odds.",
		updatedSurvivor.Id,
		updatedSurvivor.Tier,
		victimOriginal.Id,
		victimOriginal.Tier,
		survivorOdds * 100
	)

	if inheritedGene then
		logMsg ..= string.format(" Inherited +%d %s.", inheritedGene.Value, inheritedGene.Element)
	end
	if displacedGene then
		logMsg ..= string.format(" Displaced %s (%d).", displacedGene.Element, displacedGene.Value)
	end

	return true,
		{
			Success = true,
			Survivor = updatedSurvivor,
			ConsumedId = victimOriginal.Id,
			InheritedGene = inheritedGene,
			DisplacedGene = displacedGene,
			SurvivorWonOdds = survivorOdds,
			Log = logMsg,
		},
		nil
end

return table.freeze(BreedingService)
