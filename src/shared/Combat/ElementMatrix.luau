--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox
	then require(script.Parent.Parent.Types.CombatTypes)
	else require("../Types/CombatTypes")

type Element = CombatTypes.Element

local ElementMatrix = {}

local VALID_ELEMENTS: { [string]: boolean } = {
	Plasma = true,
	Cryo = true,
	Electro = true,
	Toxin = true,
	Shadow = true,
	Biomass = true,
}

-- Matrix defined in docs/GAME_DESIGN.md Section 2.1
-- [Attacker][Defender] = Multiplier
local MATRIX: { [Element]: { [Element]: number } } = {
	Plasma = {
		Plasma = 1.0,
		Cryo = 1.5,
		Electro = 0.75,
		Toxin = 1.0,
		Shadow = 0.75,
		Biomass = 1.0,
	},
	Cryo = {
		Plasma = 0.75,
		Cryo = 1.0,
		Electro = 1.0,
		Toxin = 1.0,
		Shadow = 1.0,
		Biomass = 1.5,
	},
	Electro = {
		Plasma = 1.5,
		Cryo = 1.0,
		Electro = 1.0,
		Toxin = 1.0,
		Shadow = 1.5,
		Biomass = 0.75,
	},
	Toxin = {
		Plasma = 1.0,
		Cryo = 1.5,
		Electro = 1.0,
		Toxin = 1.0,
		Shadow = 1.0,
		Biomass = 1.5,
	},
	Shadow = {
		Plasma = 1.5,
		Cryo = 1.0,
		Electro = 1.5,
		Toxin = 1.0,
		Shadow = 1.0,
		Biomass = 0.75,
	},
	Biomass = {
		Plasma = 1.0,
		Cryo = 0.75,
		Electro = 1.5,
		Toxin = 0.75,
		Shadow = 1.0,
		Biomass = 1.0,
	},
}

function ElementMatrix.IsValidElement(element: any): boolean
	return typeof(element) == "string" and VALID_ELEMENTS[element] == true
end

function ElementMatrix.GetMultiplier(
	attackerElement: Element,
	defenderElement: Element,
	attackerVoidCore: boolean?,
	defenderVoidCore: boolean?
): number
	assert(
		ElementMatrix.IsValidElement(attackerElement),
		"Invalid attacker element: " .. tostring(attackerElement)
	)
	assert(
		ElementMatrix.IsValidElement(defenderElement),
		"Invalid defender element: " .. tostring(defenderElement)
	)

	-- Section 2.2: Void Core neutralizes all multipliers to 1.0x
	if attackerVoidCore or defenderVoidCore then
		return 1.0
	end

	local attackerRow = MATRIX[attackerElement]
	if attackerRow then
		local mult = attackerRow[defenderElement]
		if mult ~= nil then
			return mult
		end
	end

	return 1.0
end

function ElementMatrix.GetCompositeMultiplier(
	attackerElement: Element,
	defenderElements: {
		Primary: Element,
		Secondary: Element?,
		Tertiary: Element?,
		TertiaryWeight: number?,
	},
	attackerVoidCore: boolean?,
	defenderVoidCore: boolean?
): number
	assert(
		ElementMatrix.IsValidElement(attackerElement),
		"Invalid attacker element: " .. tostring(attackerElement)
	)

	if attackerVoidCore or defenderVoidCore then
		return 1.0
	end

	local totalMult = ElementMatrix.GetMultiplier(attackerElement, defenderElements.Primary) * 1.0
	local totalWeight = 1.0

	if defenderElements.Secondary and ElementMatrix.IsValidElement(defenderElements.Secondary) then
		totalMult += ElementMatrix.GetMultiplier(attackerElement, defenderElements.Secondary) * 1.0
		totalWeight += 1.0
	end

	if defenderElements.Tertiary and ElementMatrix.IsValidElement(defenderElements.Tertiary) then
		local w = defenderElements.TertiaryWeight or 0
		if w > 0 then
			totalMult += ElementMatrix.GetMultiplier(attackerElement, defenderElements.Tertiary) * w
			totalWeight += w
		end
	end

	return totalMult / totalWeight
end

function ElementMatrix.GetAllElements(): { Element }
	return { "Plasma", "Cryo", "Electro", "Toxin", "Shadow", "Biomass" }
end

return table.freeze(ElementMatrix)
