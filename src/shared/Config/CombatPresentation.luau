--!strict

local CombatPresentation = {}

CombatPresentation.DummyMaxHp = 300

local attacksByMutantType = table.freeze({
	Blob = table.freeze({
		table.freeze({ Time = 1.0, Damage = 45, Impact = true, Prefix = "-", Suffix = "" }),
		table.freeze({ Time = 2.2, Damage = 45, Impact = true, Prefix = "-", Suffix = "" }),
		table.freeze({ Time = 3.4, Damage = 45, Impact = true, Prefix = "-", Suffix = "" }),
		table.freeze({ Time = 4.6, Damage = 45, Impact = true, Prefix = "-", Suffix = "" }),
	}),
	ToxicBlob = table.freeze({
		table.freeze({ Time = 0.9, Damage = 45, Impact = true, Prefix = "-", Suffix = "" }),
		table.freeze({ Time = 1.5, Damage = 15, Impact = false, Prefix = "☣ -", Suffix = " POISON" }),
		table.freeze({ Time = 2.1, Damage = 15, Impact = false, Prefix = "☣ -", Suffix = " POISON" }),
		table.freeze({ Time = 2.7, Damage = 55, Impact = true, Prefix = "-", Suffix = "" }),
		table.freeze({ Time = 3.3, Damage = 20, Impact = false, Prefix = "☣ -", Suffix = " POISON" }),
		table.freeze({ Time = 3.9, Damage = 20, Impact = false, Prefix = "☣ -", Suffix = " POISON" }),
		table.freeze({ Time = 4.5, Damage = 70, Impact = true, Prefix = "☣ TOXIC SLAM! -", Suffix = "" }),
		table.freeze({ Time = 5.0, Damage = 60, Impact = false, Prefix = "☣ FATAL POISON! -", Suffix = "" }),
	}),
	PlasmaBlob = table.freeze({
		table.freeze({ Time = 1.2, Damage = 85, Impact = true, Prefix = "⚡ -", Suffix = " LIGHTNING!" }),
		table.freeze({ Time = 2.6, Damage = 100, Impact = true, Prefix = "⚡ -", Suffix = " OVERLOAD!" }),
		table.freeze({ Time = 4.2, Damage = 115, Impact = true, Prefix = "⚡ -", Suffix = " PLASMA BURST!" }),
	}),
})

function CombatPresentation.GetAttacks(mutantType: string)
	return attacksByMutantType[mutantType] or attacksByMutantType.Blob
end

function CombatPresentation.Resolve(mutantType: string, elapsed: number): (number, number)
	local hp = CombatPresentation.DummyMaxHp
	local currentHit = 0

	for index, attack in CombatPresentation.GetAttacks(mutantType) do
		if elapsed < attack.Time then
			break
		end
		currentHit = index
		hp = math.max(0, hp - attack.Damage)
	end

	return currentHit, hp
end

function CombatPresentation.PopupText(attack): string
	return string.format("%s%d%s", attack.Prefix, attack.Damage, attack.Suffix)
end

function CombatPresentation.StepDisplayedHp(displayedHp: number, targetHp: number): number
	local nextHp = displayedHp + (targetHp - displayedHp) * 0.14
	if math.abs(nextHp - targetHp) < 0.5 then
		return targetHp
	end
	return nextHp
end

return table.freeze(CombatPresentation)
