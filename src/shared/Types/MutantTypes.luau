--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox then require(script.Parent.CombatTypes) else require("./CombatTypes")

export type Gene = CombatTypes.Gene
export type CombatRole = CombatTypes.CombatRole

export type Mutant = {
	Id: string,
	Type: string,
	Tier: number,
	Level: number,
	Role: CombatRole?,
	Genes: { Gene }?,
	RestUntil: number?,
}

export type Tutorial = {
	Started: boolean,
	FreeBlobsClaimed: number,
	FirstBlobCreated: boolean,
	FirstMergeCompleted: boolean,
	FirstBattleStarted: boolean,
	FirstBattleCompleted: boolean,
	FirstBlobPurchased: boolean,
	TutorialCompleted: boolean,
}

export type SecuredLoot = {
	BioCoins: number,
	DnaFragments: number,
	Items: { [string]: any },
}

export type Profile = {
	BreedingConsumedUnits: number?,
	DataVersion: number,
	BioCoins: number,
	SlotsUnlocked: number,
	Mutants: { Mutant },
	Tutorial: Tutorial,
	SecuredLoot: SecuredLoot?,
}

-- Battle is session-only state and must never be written into Profile.
export type Battle = {
	Id: string,
	MutantId: string,
	StartedAt: number,
	EndsAt: number,
	Reward: number,
	Consumed: boolean,
}

export type PublicBattle = {
	Id: string,
	MutantId: string,
	StartedAt: number,
	EndsAt: number,
	Reward: number,
}

export type Snapshot = {
	BioCoins: number,
	SlotsUnlocked: number,
	Mutants: { Mutant },
	Tutorial: Tutorial,
	SecuredLoot: SecuredLoot?,
	Battle: false | PublicBattle,
	Revision: number,
	PersistenceMode: string,
}

return {}
