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

local RestCooldownService = {}

local REST_DURATION_SECONDS = 120 -- 2 minutes per docs/GAME_DESIGN.md Section 6.3
local BONUS_MUTATION_CHANCE = 0.40 -- 40% chance of mutation after resting

export type MutationBonus = {
	Element: Element,
	ValueAdded: number,
	IsNewGene: boolean,
}

function RestCooldownService.GetRestDuration(): number
	return REST_DURATION_SECONDS
end

function RestCooldownService.IsOnRest(mutant: Mutant, now: number): boolean
	if mutant.RestUntil ~= nil and mutant.RestUntil > now then
		return true
	end
	return false
end

function RestCooldownService.GetRemainingRest(mutant: Mutant, now: number): number
	if mutant.RestUntil == nil then
		return 0
	end
	return math.max(0, mutant.RestUntil - now)
end

function RestCooldownService.StartRest(mutant: Mutant, now: number): Mutant
	local updated = table.clone(mutant)
	updated.RestUntil = now + REST_DURATION_SECONDS
	return updated
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

function RestCooldownService.CompleteRest(
	mutant: Mutant,
	now: number,
	rng: (() -> number)?
): (Mutant, MutationBonus?)
	local rand = if rng then rng else math.random

	local updated = table.clone(mutant)
	updated.RestUntil = nil

	local bonus: MutationBonus? = nil
	local genes = cloneGenes(updated.Genes)

	-- Check for bonus mutation post-rest
	if rand() < BONUS_MUTATION_CHANCE and #genes > 0 then
		-- Select random existing gene to boost
		local idx = math.clamp(math.floor(rand() * #genes) + 1, 1, #genes)
		local boostVal = math.floor(rand() * 11) + 5 -- 5 to 15
		genes[idx].Value = math.clamp(genes[idx].Value + boostVal, 1, 100)

		bonus = {
			Element = genes[idx].Element,
			ValueAdded = boostVal,
			IsNewGene = false,
		}
		updated.Genes = genes
	end

	return updated, bonus
end

return table.freeze(RestCooldownService)
