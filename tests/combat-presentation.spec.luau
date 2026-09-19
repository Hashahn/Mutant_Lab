local CombatPresentation = require("../src/shared/Config/CombatPresentation")

local expected = {
	Blob = {
		FinalHp = 120,
		Popups = { "-45", "-45", "-45", "-45" },
	},
	ToxicBlob = {
		FinalHp = 0,
		Popups = {
			"-45",
			"☣ -15 POISON",
			"☣ -15 POISON",
			"-55",
			"☣ -20 POISON",
			"☣ -20 POISON",
			"☣ TOXIC SLAM! -70",
			"☣ FATAL POISON! -60",
		},
	},
	PlasmaBlob = {
		FinalHp = 0,
		Popups = { "⚡ -85 LIGHTNING!", "⚡ -100 OVERLOAD!", "⚡ -115 PLASMA BURST!" },
	},
}

for mutantType, expectation in expected do
	local attacks = CombatPresentation.GetAttacks(mutantType)
	local expectedHp = CombatPresentation.DummyMaxHp
	local previousTime = -math.huge

	for index, attack in attacks do
		assert(attack.Time > previousTime, mutantType .. " attack times must increase")
		assert(attack.Damage > 0, mutantType .. " damage must be positive")
		previousTime = attack.Time
		expectedHp = math.max(0, expectedHp - attack.Damage)

		local currentHit, resolvedHp = CombatPresentation.Resolve(mutantType, attack.Time)
		assert(currentHit == index, mutantType .. " resolved the wrong hit index")
		assert(resolvedHp == expectedHp, mutantType .. " HP delta disagrees with displayed damage")
		assert(
			CombatPresentation.PopupText(attack) == expectation.Popups[index],
			mutantType .. " popup disagrees with configured damage"
		)
	end

	local _, finalHp = CombatPresentation.Resolve(mutantType, math.huge)
	assert(finalHp == expectation.FinalHp, mutantType .. " final HP is wrong")
end

local _, fallbackHp = CombatPresentation.Resolve("UnknownMutant", math.huge)
assert(fallbackHp == expected.Blob.FinalHp, "unknown presentation must fall back to Blob")

for _, targetHp in { expected.Blob.FinalHp, expected.ToxicBlob.FinalHp, expected.PlasmaBlob.FinalHp } do
	local displayedHp = CombatPresentation.DummyMaxHp
	for _ = 1, 120 do
		displayedHp = CombatPresentation.StepDisplayedHp(displayedHp, targetHp)
	end
	assert(displayedHp == targetHp, "smoothed HP must settle on its exact endpoint")
end

print("PASS combat presentation: popup damage matches HP deltas and final HP")
