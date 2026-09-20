--!strict
local isRoblox = typeof(script) == "Instance"
local CombatTypes = if isRoblox then require(script.Parent.CombatTypes) else require("./CombatTypes")

export type RoomType = "Entrance" | "Combat" | "Terminal" | "Boss"

export type LootBundle = {
	BioCoins: number,
	DnaFragments: number,
	Items: { string },
}

export type ExpeditionRoom = {
	Index: number,
	Type: RoomType,
	Title: string,
	EnemySquad: CombatTypes.SquadInput?,
	Loot: LootBundle,
	HasTerminal: boolean,
}

export type ExpeditionStatus = "Exploring" | "InCombat" | "AtTerminal" | "Completed" | "Failed"

export type ExpeditionSnapshot = {
	Id: string,
	TotalRooms: number,
	CurrentRoomIndex: number,
	Status: ExpeditionStatus,
	RoomTitle: string,
	RoomType: RoomType,
	HasTerminal: boolean,
	PendingLoot: LootBundle,
	SecuredLoot: LootBundle,
	InCombat: boolean,
	CurrentCombat: CombatTypes.CombatState?,
}

return {}
