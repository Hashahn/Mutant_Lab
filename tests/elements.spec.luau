--!strict

local ElementMatrix = require("../src/shared/Combat/ElementMatrix")

print("Running elements.spec.luau")

-- 1. Validation
local allElements = ElementMatrix.GetAllElements()
assert(#allElements == 6, "Must have exactly 6 elements")
for _, elem in allElements do
	assert(ElementMatrix.IsValidElement(elem), "Element must be valid: " .. elem)
end
assert(not ElementMatrix.IsValidElement("Fire"), "Fire must be invalid")
assert(not ElementMatrix.IsValidElement("Water"), "Water must be invalid")
assert(not ElementMatrix.IsValidElement(123), "Number must be invalid")

-- 2. Exact multipliers from docs/GAME_DESIGN.md Section 2.1
-- Plasma
assert(ElementMatrix.GetMultiplier("Plasma", "Cryo") == 1.5, "Plasma -> Cryo must be 1.5x")
assert(ElementMatrix.GetMultiplier("Plasma", "Electro") == 0.75, "Plasma -> Electro must be 0.75x")
assert(ElementMatrix.GetMultiplier("Plasma", "Shadow") == 0.75, "Plasma -> Shadow must be 0.75x")
assert(ElementMatrix.GetMultiplier("Plasma", "Biomass") == 1.0, "Plasma -> Biomass must be 1.0x")
assert(ElementMatrix.GetMultiplier("Plasma", "Plasma") == 1.0, "Plasma -> Plasma must be 1.0x")

-- Cryo
assert(ElementMatrix.GetMultiplier("Cryo", "Biomass") == 1.5, "Cryo -> Biomass must be 1.5x")
assert(ElementMatrix.GetMultiplier("Cryo", "Plasma") == 0.75, "Cryo -> Plasma must be 0.75x")
assert(ElementMatrix.GetMultiplier("Cryo", "Electro") == 1.0, "Cryo -> Electro must be 1.0x")

-- Electro
assert(ElementMatrix.GetMultiplier("Electro", "Plasma") == 1.5, "Electro -> Plasma must be 1.5x")
assert(ElementMatrix.GetMultiplier("Electro", "Shadow") == 1.5, "Electro -> Shadow must be 1.5x")
assert(ElementMatrix.GetMultiplier("Electro", "Biomass") == 0.75, "Electro -> Biomass must be 0.75x")

-- Toxin
assert(ElementMatrix.GetMultiplier("Toxin", "Cryo") == 1.5, "Toxin -> Cryo must be 1.5x")
assert(ElementMatrix.GetMultiplier("Toxin", "Biomass") == 1.5, "Toxin -> Biomass must be 1.5x")
assert(ElementMatrix.GetMultiplier("Toxin", "Plasma") == 1.0, "Toxin -> Plasma must be 1.0x")

-- Shadow
assert(ElementMatrix.GetMultiplier("Shadow", "Plasma") == 1.5, "Shadow -> Plasma must be 1.5x")
assert(ElementMatrix.GetMultiplier("Shadow", "Electro") == 1.5, "Shadow -> Electro must be 1.5x")
assert(ElementMatrix.GetMultiplier("Shadow", "Biomass") == 0.75, "Shadow -> Biomass must be 0.75x")

-- Biomass
assert(ElementMatrix.GetMultiplier("Biomass", "Electro") == 1.5, "Biomass -> Electro must be 1.5x")
assert(ElementMatrix.GetMultiplier("Biomass", "Cryo") == 0.75, "Biomass -> Cryo must be 0.75x")
assert(ElementMatrix.GetMultiplier("Biomass", "Toxin") == 0.75, "Biomass -> Toxin must be 0.75x")

-- 3. Void Core mechanics (docs/GAME_DESIGN.md Section 2.2)
-- Attacker with Void Core
assert(
	ElementMatrix.GetMultiplier("Plasma", "Cryo", true, false) == 1.0,
	"Attacker Void Core must neutralize advantage"
)
assert(
	ElementMatrix.GetMultiplier("Plasma", "Electro", true, false) == 1.0,
	"Attacker Void Core must neutralize disadvantage"
)

-- Defender with Void Core
assert(
	ElementMatrix.GetMultiplier("Plasma", "Cryo", false, true) == 1.0,
	"Defender Void Core must neutralize incoming advantage"
)
assert(
	ElementMatrix.GetMultiplier("Plasma", "Electro", false, true) == 1.0,
	"Defender Void Core must neutralize incoming disadvantage"
)

-- Both with Void Core
assert(
	ElementMatrix.GetMultiplier("Plasma", "Cryo", true, true) == 1.0,
	"Both with Void Core must neutralize to 1.0x"
)

print("PASS elements: all 6 elements and Void Core verified")
