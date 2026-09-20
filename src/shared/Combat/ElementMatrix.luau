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

function ElementMatrix.GetAllElements(): { Element }
	return { "Plasma", "Cryo", "Electro", "Toxin", "Shadow", "Biomass" }
end

return table.freeze(ElementMatrix)
