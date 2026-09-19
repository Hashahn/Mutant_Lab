--!strict

export type Mutant = {
	Id: string,
	Type: string,
	Tier: number,
	Level: number,
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

export type Profile = {
	DataVersion: number,
	BioCoins: number,
	SlotsUnlocked: number,
	Mutants: { Mutant },
	Tutorial: Tutorial,
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
	Battle: false | PublicBattle,
	Revision: number,
	PersistenceMode: string,
}

return {}
