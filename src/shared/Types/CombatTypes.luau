--!strict

export type Element = "Plasma" | "Cryo" | "Electro" | "Toxin" | "Shadow" | "Biomass"

export type CombatRole = "Striker" | "Guardian" | "Healer" | "Buffer" | "Controller"

export type Gene = {
	Element: Element,
	Value: number,
}

export type EffectiveElements = {
	Primary: Element,
	Secondary: Element?,
	Tertiary: Element?,
	TertiaryWeight: number,
}

export type CalculatedStats = {
	MaxHp: number,
	Speed: number,
	Attack: number,
	AutoGuardChance: number,
	EffectiveElements: EffectiveElements,
}

export type AbilityType = "Basic" | "RoleSkill" | "Ultimate"

export type Ability = {
	Name: string,
	Type: AbilityType,
	EnergyCost: number,
	EnergyGain: number,
	PowerMultiplier: number,
	Cooldown: number,
	TargetType: "SingleEnemy" | "AllEnemies" | "SingleAlly" | "AllAllies" | "Self",
	Element: Element?,
}

export type CombatUnit = {
	Id: string,
	Name: string,
	Tier: number,
	Role: CombatRole,
	Genes: { Gene },
	Stats: CalculatedStats,
	CurrentHp: number,
	MaxHp: number,
	IsAlive: boolean,
	HasVoidCore: boolean,
	TauntTurns: number,
	GuardTurns: number,
	Cooldowns: { [string]: number },
	Abilities: { Ability },
}

export type TeamSide = "Player" | "Enemy"

export type TeamState = {
	Side: TeamSide,
	Active: { CombatUnit },
	Reserve: { CombatUnit },
	Energy: number,
	MaxEnergy: number,
	PassiveEnergyPerRound: number,
	ReserveDeployed: boolean,
}

export type CombatAction = {
	ActorId: string,
	AbilityType: AbilityType,
	TargetId: string?,
}

export type CombatLogEntry = {
	Round: number,
	ActorId: string,
	ActionType: AbilityType,
	TargetId: string?,
	Damage: number?,
	Heal: number?,
	IsCritical: boolean?,
	IsGuarded: boolean?,
	ElementMultiplier: number?,
	Message: string,
}

export type CombatStatus = "InProgress" | "Victory" | "Defeat"

export type CombatState = {
	Id: string,
	Round: number,
	TurnIndex: number,
	InitiativeQueue: { string },
	CurrentTurnUnitId: string,
	PlayerTeam: TeamState,
	EnemyTeam: TeamState,
	Status: CombatStatus,
	Log: { CombatLogEntry },
}

return {}
