--!strict
local isRoblox = typeof(script) == "Instance" and typeof(game) == "Instance"
local root = if isRoblox then game:GetService("ReplicatedStorage"):WaitForChild("MutantLab") else nil
local shared = if root then root:WaitForChild("Shared") else nil

local CombatTypes = if isRoblox
	then require(shared.Types.CombatTypes)
	else require("../../shared/Types/CombatTypes")
local ExpeditionTypes = if isRoblox
	then require(shared.Types.ExpeditionTypes)
	else require("../../shared/Types/ExpeditionTypes")

type RoomType = ExpeditionTypes.RoomType
type LootBundle = ExpeditionTypes.LootBundle
type ExpeditionRoom = ExpeditionTypes.ExpeditionRoom
type SquadInput = CombatTypes.SquadInput

local ExpeditionGenerator = {}

local function generateEnemySquad(difficulty: number, rng: () -> number): SquadInput
	local activeUnits: { CombatTypes.UnitInput } = {}
	local count = if difficulty >= 3 then 3 else (if difficulty == 2 then 2 else 1)

	local roles: { CombatTypes.CombatRole } = { "Striker", "Guardian", "Controller", "Buffer" }
	local elements: { CombatTypes.Element } = { "Plasma", "Cryo", "Electro", "Toxin", "Shadow", "Biomass" }

	for i = 1, count do
		local role = roles[math.clamp(math.floor(rng() * #roles) + 1, 1, #roles)]
		local elem1 = elements[math.clamp(math.floor(rng() * #elements) + 1, 1, #elements)]
		local elem2 = elements[math.clamp(math.floor(rng() * #elements) + 1, 1, #elements)]

		local tier = if difficulty >= 4 and i == 1 then 3 else (if difficulty >= 2 then 2 else 1)
		local geneVal = 20 + difficulty * 15

		table.insert(activeUnits, {
			Id = string.format("enemy_d%d_%d", difficulty, i),
			Name = string.format("%s %s", elem1, role),
			Tier = tier,
			Role = role,
			Genes = {
				{ Element = elem1, Value = geneVal },
				{ Element = elem2, Value = math.floor(geneVal * 0.7) },
			},
		})
	end

	return {
		Active = activeUnits,
		Reserve = nil,
	}
end

function ExpeditionGenerator.GenerateChain(roomCount: number, rngFunc: (() -> number)?): { ExpeditionRoom }
	assert(roomCount == 3 or roomCount == 5, "Expedition room count must be 3 or 5")
	local rng = if rngFunc then rngFunc else math.random

	local rooms: { ExpeditionRoom } = {}

	if roomCount == 3 then
		-- Room 1: Entrance scout
		table.insert(rooms, {
			Index = 1,
			Type = "Entrance",
			Title = "Abandoned Intake Corridor",
			EnemySquad = generateEnemySquad(1, rng),
			Loot = {
				BioCoins = 30,
				DnaFragments = 1,
				Items = {},
			},
			HasTerminal = false,
		})

		-- Room 2: Intermediate checkpoint & terminal
		table.insert(rooms, {
			Index = 2,
			Type = "Terminal",
			Title = "Decontamination Hub & Terminal",
			EnemySquad = generateEnemySquad(2, rng),
			Loot = {
				BioCoins = 60,
				DnaFragments = 2,
				Items = { "DnaSample_Cryo" },
			},
			HasTerminal = true,
		})

		-- Room 3: Sector Boss & Main Evacuation
		table.insert(rooms, {
			Index = 3,
			Type = "Boss",
			Title = "Genesis Reactor Core",
			EnemySquad = generateEnemySquad(4, rng),
			Loot = {
				BioCoins = 150,
				DnaFragments = 5,
				Items = { "VoidCore" },
			},
			HasTerminal = true,
		})
	else
		-- 5-room deep expedition
		table.insert(rooms, {
			Index = 1,
			Type = "Entrance",
			Title = "Outer Perimeter Gate",
			EnemySquad = generateEnemySquad(1, rng),
			Loot = {
				BioCoins = 30,
				DnaFragments = 1,
				Items = {},
			},
			HasTerminal = false,
		})

		table.insert(rooms, {
			Index = 2,
			Type = "Combat",
			Title = "Specimen Cryo-Archive",
			EnemySquad = generateEnemySquad(2, rng),
			Loot = {
				BioCoins = 50,
				DnaFragments = 2,
				Items = {},
			},
			HasTerminal = false,
		})

		table.insert(rooms, {
			Index = 3,
			Type = "Terminal",
			Title = "Central Quarantine Relay",
			EnemySquad = generateEnemySquad(3, rng),
			Loot = {
				BioCoins = 80,
				DnaFragments = 3,
				Items = { "DnaSample_Toxin" },
			},
			HasTerminal = true,
		})

		table.insert(rooms, {
			Index = 4,
			Type = "Combat",
			Title = "High-Voltage Conduit Sector",
			EnemySquad = generateEnemySquad(3, rng),
			Loot = {
				BioCoins = 100,
				DnaFragments = 4,
				Items = {},
			},
			HasTerminal = false,
		})

		table.insert(rooms, {
			Index = 5,
			Type = "Boss",
			Title = "Genesis Prime Vault",
			EnemySquad = generateEnemySquad(5, rng),
			Loot = {
				BioCoins = 250,
				DnaFragments = 8,
				Items = { "VoidCore" },
			},
			HasTerminal = true,
		})
	end

	return rooms
end

return table.freeze(ExpeditionGenerator)
