--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox
	then require(script.Parent.Parent.Types.CombatTypes)
	else require("../Types/CombatTypes")

type Element = CombatTypes.Element
type CombatRole = CombatTypes.CombatRole
type Gene = CombatTypes.Gene
type EffectiveElements = CombatTypes.EffectiveElements
type CalculatedStats = CombatTypes.CalculatedStats
type Ability = CombatTypes.Ability

local MutantStats = {}

local BASE_HP_BY_TIER: { [number]: number } = {
	[1] = 100,
	[2] = 180,
	[3] = 300,
}

local BASE_ATTACK_BY_TIER: { [number]: number } = {
	[1] = 20,
	[2] = 35,
	[3] = 60,
}

local BASE_SPEED = 100

-- Sort genes by Value descending, tie-breaking by Element name
local function sortGenes(genes: { Gene }): { Gene }
	local sorted = table.clone(genes)
	table.sort(sorted, function(a, b)
		if a.Value == b.Value then
			return a.Element < b.Element
		end
		return a.Value > b.Value
	end)
	return sorted
end

function MutantStats.CalculateEffectiveElements(tier: number, genes: { Gene }): EffectiveElements
	local sorted = sortGenes(genes)
	local primary: Element = if #sorted > 0 then sorted[1].Element else "Biomass"
	local secondary: Element? = if #sorted > 1 then sorted[2].Element else nil
	local tertiary: Element? = nil
	local tertiaryWeight = 0.0

	if tier == 1 then
		-- Tier 1 (3 genes): 2 strongest determine active elements (100%), 3rd is passive reserve
		tertiary = nil
		tertiaryWeight = 0.0
	elseif tier == 2 then
		-- Tier 2 (4 genes): 2 strongest are 100%, 3rd acts at 50% power, 4th hidden
		if #sorted >= 3 then
			tertiary = sorted[3].Element
			tertiaryWeight = 0.5
		end
	elseif tier >= 3 then
		-- Tier 3 (5 genes): 3 strongest genes are 100% active, remaining hidden
		if #sorted >= 3 then
			tertiary = sorted[3].Element
			tertiaryWeight = 1.0
		end
	end

	return {
		Primary = primary,
		Secondary = secondary,
		Tertiary = tertiary,
		TertiaryWeight = tertiaryWeight,
	}
end

function MutantStats.CalculateStats(tier: number, genes: { Gene }, role: CombatRole?): CalculatedStats
	local effectiveElements = MutantStats.CalculateEffectiveElements(tier, genes)
	local sorted = sortGenes(genes)

	local baseHp = BASE_HP_BY_TIER[tier] or 100
	local baseAttack = BASE_ATTACK_BY_TIER[tier] or 20
	local speed = BASE_SPEED

	local biomassVal = 0
	local cryoVal = 0
	local electroVal = 0
	local shadowVal = 0
	local totalGeneVal = 0

	for _, g in genes do
		totalGeneVal += g.Value
		if g.Element == "Biomass" then
			biomassVal += g.Value
		elseif g.Element == "Cryo" then
			cryoVal += g.Value
		elseif g.Element == "Electro" then
			electroVal += g.Value
		elseif g.Element == "Shadow" then
			shadowVal += g.Value
		end
	end

	-- Biomass and Cryo provide substantial Max HP scaling
	local hpBonus = math.floor(biomassVal * 1.5 + cryoVal * 1.0 + (totalGeneVal - biomassVal - cryoVal) * 0.5)
	local maxHp = baseHp + hpBonus

	-- Electro and Shadow provide Speed scaling
	local speedBonus = math.floor(electroVal * 0.4 + shadowVal * 0.3)
	speed += speedBonus

	-- Primary gene provides direct Attack scaling
	local primaryGeneVal = if #sorted > 0 then sorted[1].Value else 0
	local secondaryGeneVal = if #sorted > 1 then sorted[2].Value else 0
	local attackBonus = math.floor(primaryGeneVal * 0.5 + secondaryGeneVal * 0.25)
	local attack = baseAttack + attackBonus

	-- Role modifiers
	local assignedRole = role or "Striker"
	if assignedRole == "Guardian" then
		maxHp = math.floor(maxHp * 1.25)
		speed = math.floor(speed * 0.9)
	elseif assignedRole == "Striker" then
		attack = math.floor(attack * 1.2)
	elseif assignedRole == "Controller" then
		speed = math.floor(speed * 1.15)
	end

	-- Passive auto-guard chance: 5% base + scaling from defensive genes (cap at 35%)
	local guardDef = biomassVal + cryoVal
	local autoGuardChance = math.clamp(0.05 + (guardDef * 0.002), 0.05, 0.35)

	return {
		MaxHp = maxHp,
		Speed = speed,
		Attack = attack,
		AutoGuardChance = autoGuardChance,
		EffectiveElements = effectiveElements,
	}
end

function MutantStats.BuildAbilities(tier: number, role: CombatRole, stats: CalculatedStats): { Ability }
	local primaryElement = stats.EffectiveElements.Primary

	local basicAbility: Ability = {
		Name = primaryElement .. " Strike",
		Type = "Basic",
		EnergyCost = 0,
		EnergyGain = 1,
		PowerMultiplier = 1.0,
		Cooldown = 0,
		TargetType = "SingleEnemy",
		Element = primaryElement,
	}

	local roleAbility: Ability
	if role == "Guardian" then
		roleAbility = {
			Name = "Bulwark Taunt",
			Type = "RoleSkill",
			EnergyCost = 2,
			EnergyGain = 0,
			PowerMultiplier = 0.5,
			Cooldown = 2,
			TargetType = "SingleEnemy",
			Element = primaryElement,
		}
	elseif role == "Healer" then
		roleAbility = {
			Name = "Bio-Mend",
			Type = "RoleSkill",
			EnergyCost = 2,
			EnergyGain = 0,
			PowerMultiplier = 1.2,
			Cooldown = 2,
			TargetType = "SingleAlly",
			Element = primaryElement,
		}
	elseif role == "Buffer" then
		roleAbility = {
			Name = "Surge Boost",
			Type = "RoleSkill",
			EnergyCost = 2,
			EnergyGain = 0,
			PowerMultiplier = 0.0,
			Cooldown = 2,
			TargetType = "AllAllies",
			Element = primaryElement,
		}
	elseif role == "Controller" then
		roleAbility = {
			Name = "Neural Disrupt",
			Type = "RoleSkill",
			EnergyCost = 2,
			EnergyGain = 0,
			PowerMultiplier = 0.8,
			Cooldown = 2,
			TargetType = "SingleEnemy",
			Element = primaryElement,
		}
	else -- Striker default
		roleAbility = {
			Name = "Power Slam",
			Type = "RoleSkill",
			EnergyCost = 2,
			EnergyGain = 0,
			PowerMultiplier = 1.75,
			Cooldown = 1,
			TargetType = "SingleEnemy",
			Element = primaryElement,
		}
	end

	local ultimateAbility: Ability = {
		Name = primaryElement .. " Cataclysm",
		Type = "Ultimate",
		EnergyCost = 5,
		EnergyGain = 0,
		PowerMultiplier = 2.5,
		Cooldown = 3,
		TargetType = "SingleEnemy",
		Element = primaryElement,
	}

	return { basicAbility, roleAbility, ultimateAbility }
end

return table.freeze(MutantStats)
