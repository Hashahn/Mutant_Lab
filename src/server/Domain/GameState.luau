--!strict

local GameState = {}

local PROFILE_REQUIRED_KEYS = {
	DataVersion = true,
	BioCoins = true,
	SlotsUnlocked = true,
	Mutants = true,
	Tutorial = true,
	SecuredLoot = true,
}

local PROFILE_KEYS = {
	DataVersion = true,
	BioCoins = true,
	SlotsUnlocked = true,
	Mutants = true,
	Tutorial = true,
	SecuredLoot = true,
	BreedingConsumedUnits = true,
}

local MUTANT_KEYS = {
	Id = true,
	Type = true,
	Tier = true,
	Level = true,
	Role = true,
	Genes = true,
	RestUntil = true,
}

local MUTANT_REQUIRED_KEYS = {
	Id = true,
	Type = true,
	Tier = true,
	Level = true,
}

local SECURED_LOOT_KEYS = {
	BioCoins = true,
	DnaFragments = true,
	Items = true,
}

local VALID_ROLES = {
	Striker = true,
	Guardian = true,
	Healer = true,
	Buffer = true,
	Controller = true,
}

local VALID_ELEMENTS = {
	Plasma = true,
	Cryo = true,
	Electro = true,
	Toxin = true,
	Shadow = true,
	Biomass = true,
}

local MAX_GENE_SLOTS_BY_TIER: { [number]: number } = {
	[1] = 3,
	[2] = 4,
	[3] = 5,
}

local STARTER_GENES_BY_TIER: { [number]: { { Element: string, Value: number } } } = {
	[1] = {
		{ Element = "Biomass", Value = 25 },
		{ Element = "Plasma", Value = 20 },
		{ Element = "Cryo", Value = 10 },
	},
	[2] = {
		{ Element = "Toxin", Value = 50 },
		{ Element = "Biomass", Value = 35 },
		{ Element = "Cryo", Value = 25 },
		{ Element = "Shadow", Value = 15 },
	},
	[3] = {
		{ Element = "Plasma", Value = 85 },
		{ Element = "Electro", Value = 65 },
		{ Element = "Shadow", Value = 45 },
		{ Element = "Cryo", Value = 30 },
		{ Element = "Biomass", Value = 20 },
	},
}

local TUTORIAL_KEYS = {
	Started = true,
	FreeBlobsClaimed = true,
	FirstBlobCreated = true,
	FirstMergeCompleted = true,
	FirstBattleStarted = true,
	FirstBattleCompleted = true,
	FirstBlobPurchased = true,
	TutorialCompleted = true,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isInteger(value: any): boolean
	return isFiniteNumber(value) and value % 1 == 0
end

local function deepCopy(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end

	local copies = seen or {}
	if copies[value] ~= nil then
		return copies[value]
	end

	local result = {}
	copies[value] = result
	for key, child in pairs(value) do
		result[deepCopy(key, copies)] = deepCopy(child, copies)
	end
	return result
end

local function hasExactKeys(value: any, expected: { [string]: boolean }): boolean
	if type(value) ~= "table" then
		return false
	end

	for key in pairs(value) do
		if type(key) ~= "string" or not expected[key] then
			return false
		end
	end

	for key in pairs(expected) do
		if value[key] == nil then
			return false
		end
	end

	return true
end

local function isStrictArray(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	local length = #value
	local count = 0
	for key in pairs(value) do
		if not isInteger(key) or key < 1 or key > length then
			return false
		end
		count += 1
	end

	return count == length
end

function GameState.migrateProfile(profile: any, _gameConfig: any, _mutantConfig: any): any
	if type(profile) ~= "table" then
		return profile
	end

	if profile.DataVersion == 2 then
		return deepCopy(profile)
	end

	if profile.DataVersion ~= 1 then
		return profile
	end

	local migrated = deepCopy(profile)
	migrated.DataVersion = 2

	if type(migrated.SecuredLoot) ~= "table" then
		migrated.SecuredLoot = {
			BioCoins = 0,
			DnaFragments = 0,
			Items = {},
		}
	end

	if type(migrated.Mutants) == "table" then
		for _, mutant in ipairs(migrated.Mutants) do
			if type(mutant) == "table" then
				if mutant.Role == nil or not VALID_ROLES[mutant.Role] then
					mutant.Role = "Striker"
				end
				if mutant.Genes == nil or type(mutant.Genes) ~= "table" or #mutant.Genes == 0 then
					local starter = STARTER_GENES_BY_TIER[mutant.Tier] or STARTER_GENES_BY_TIER[1]
					mutant.Genes = deepCopy(starter)
				end
			end
		end
	end

	return migrated
end

function GameState.newProfile(gameConfig: any): any
	return {
		DataVersion = gameConfig.DataVersion,
		BioCoins = gameConfig.StartingBioCoins,
		SlotsUnlocked = gameConfig.StartingSlots,
		Mutants = {},
		Tutorial = {
			Started = false,
			FreeBlobsClaimed = 0,
			FirstBlobCreated = false,
			FirstMergeCompleted = false,
			FirstBattleStarted = false,
			FirstBattleCompleted = false,
			FirstBlobPurchased = false,
			TutorialCompleted = false,
		},
		SecuredLoot = {
			BioCoins = 0,
			DnaFragments = 0,
			Items = {},
		},
	}
end

function GameState.validateProfile(profile: any, gameConfig: any, mutantConfig: any): boolean
	if type(profile) ~= "table" then
		return false
	end
	for key in pairs(profile) do
		if not PROFILE_KEYS[key] then
			return false
		end
	end
	for key in pairs(PROFILE_REQUIRED_KEYS) do
		if profile[key] == nil then
			return false
		end
	end
	if profile.BreedingConsumedUnits ~= nil then
		if not isInteger(profile.BreedingConsumedUnits) or profile.BreedingConsumedUnits < 0 then
			return false
		end
	end

	-- Old data must be migrated before validation. Future data is rejected rather
	-- than silently interpreted by an older server.
	if not isInteger(profile.DataVersion) or profile.DataVersion ~= gameConfig.DataVersion then
		return false
	end
	if
		not isInteger(profile.BioCoins)
		or profile.BioCoins < 0
		or profile.BioCoins > gameConfig.MaxBioCoins
	then
		return false
	end
	if not isInteger(profile.SlotsUnlocked) or profile.SlotsUnlocked ~= gameConfig.StartingSlots then
		return false
	end
	if not isStrictArray(profile.Mutants) or #profile.Mutants > profile.SlotsUnlocked then
		return false
	end

	local securedLoot = profile.SecuredLoot
	if not hasExactKeys(securedLoot, SECURED_LOOT_KEYS) then
		return false
	end
	if
		not isInteger(securedLoot.BioCoins)
		or securedLoot.BioCoins < 0
		or not isInteger(securedLoot.DnaFragments)
		or securedLoot.DnaFragments < 0
		or type(securedLoot.Items) ~= "table"
	then
		return false
	end

	local ids = {}
	local acquisitionUnits = 0
	local hasToxicBlob = false
	for _, mutant in ipairs(profile.Mutants) do
		if type(mutant) ~= "table" then
			return false
		end
		for key in pairs(mutant) do
			if type(key) ~= "string" or not MUTANT_KEYS[key] then
				return false
			end
		end
		for key in pairs(MUTANT_REQUIRED_KEYS) do
			if mutant[key] == nil then
				return false
			end
		end
		if type(mutant.Id) ~= "string" or #mutant.Id < 1 or #mutant.Id > 64 or ids[mutant.Id] then
			return false
		end
		if type(mutant.Type) ~= "string" then
			return false
		end
		local definition = mutantConfig[mutant.Type]
		if type(definition) ~= "table" or mutant.Tier ~= definition.Tier then
			return false
		end
		if
			not isInteger(mutant.Tier)
			or mutant.Tier < 1
			or not isInteger(mutant.Level)
			or mutant.Level < 1
			or mutant.Level > 20
		then
			return false
		end
		if mutant.Role ~= nil and (type(mutant.Role) ~= "string" or not VALID_ROLES[mutant.Role]) then
			return false
		end
		if mutant.RestUntil ~= nil and not isFiniteNumber(mutant.RestUntil) then
			return false
		end
		if mutant.Genes ~= nil then
			if not isStrictArray(mutant.Genes) then
				return false
			end
			local maxSlots = MAX_GENE_SLOTS_BY_TIER[mutant.Tier] or 3
			if #mutant.Genes > maxSlots then
				return false
			end
			local geneElements = {}
			for _, gene in ipairs(mutant.Genes) do
				if type(gene) ~= "table" then
					return false
				end
				if type(gene.Element) ~= "string" or not VALID_ELEMENTS[gene.Element] then
					return false
				end
				if not isInteger(gene.Value) or gene.Value < 1 or gene.Value > 100 then
					return false
				end
				if geneElements[gene.Element] then
					return false
				end
				geneElements[gene.Element] = true
			end
		end
		if mutant.Type == "Blob" then
			acquisitionUnits += 1
		elseif
			mutant.Type == "ToxicBlob"
			or mutant.Type == "CryoBlob"
			or mutant.Type == "ElectroBlob"
			or mutant.Type == "ShadowBlob"
		then
			acquisitionUnits += 2
			hasToxicBlob = true
		elseif mutant.Type == "PlasmaBlob" then
			acquisitionUnits += 4
			hasToxicBlob = true
		else
			return false
		end
		ids[mutant.Id] = true
	end

	local tutorial = profile.Tutorial
	if not hasExactKeys(tutorial, TUTORIAL_KEYS) then
		return false
	end
	if
		not isInteger(tutorial.FreeBlobsClaimed)
		or tutorial.FreeBlobsClaimed < 0
		or tutorial.FreeBlobsClaimed > gameConfig.FreeTutorialBlobs
	then
		return false
	end
	for key in pairs(TUTORIAL_KEYS) do
		if key ~= "FreeBlobsClaimed" and type(tutorial[key]) ~= "boolean" then
			return false
		end
	end

	if tutorial.FreeBlobsClaimed > 0 and (not tutorial.Started or not tutorial.FirstBlobCreated) then
		return false
	end
	if
		tutorial.FirstBlobCreated
		and (not tutorial.Started or tutorial.FreeBlobsClaimed < 1 or #profile.Mutants < 1)
	then
		return false
	end
	if
		#profile.Mutants == 0
		and (
			tutorial.FreeBlobsClaimed ~= 0
			or tutorial.FirstBlobCreated
			or tutorial.FirstMergeCompleted
			or tutorial.FirstBattleStarted
			or tutorial.FirstBattleCompleted
			or tutorial.FirstBlobPurchased
			or tutorial.TutorialCompleted
		)
	then
		return false
	end
	if #profile.Mutants > 0 and not tutorial.FirstBlobCreated then
		return false
	end
	if tutorial.FirstMergeCompleted and (not tutorial.FirstBlobCreated or tutorial.FreeBlobsClaimed < 2) then
		return false
	end
	if tutorial.FirstBattleStarted and not tutorial.FirstBlobCreated then
		return false
	end
	if tutorial.FirstBattleCompleted and not tutorial.FirstBattleStarted then
		return false
	end
	if tutorial.FirstBlobPurchased and tutorial.FreeBlobsClaimed < gameConfig.FreeTutorialBlobs then
		return false
	end
	if tutorial.TutorialCompleted and not tutorial.FirstBattleCompleted then
		return false
	end
	if not tutorial.TutorialCompleted and not tutorial.FirstMergeCompleted and hasToxicBlob then
		return false
	end

	-- Merging preserves acquired tier-1 units: Blob counts as one and
	-- ToxicBlob as two. Without a paid Blob, this must equal the persisted
	-- free-create count. Paid profiles may shrink only after release unlocks.
	local totalAcquiredUnits = acquisitionUnits + (profile.BreedingConsumedUnits or 0)
	if not tutorial.FirstBlobPurchased and totalAcquiredUnits ~= tutorial.FreeBlobsClaimed then
		return false
	end
	if
		tutorial.FirstBlobPurchased
		and not tutorial.TutorialCompleted
		and totalAcquiredUnits < tutorial.FreeBlobsClaimed + 1
	then
		return false
	end

	return true
end

function GameState.snapshot(profile: any, battle: any, revision: number, mode: string): any
	local mutants = {}
	for index, mutant in ipairs(profile.Mutants) do
		mutants[index] = {
			Id = mutant.Id,
			Type = mutant.Type,
			Tier = mutant.Tier,
			Level = mutant.Level,
			Role = mutant.Role or "Striker",
			Genes = if mutant.Genes then deepCopy(mutant.Genes) else nil,
			RestUntil = mutant.RestUntil,
		}
	end

	local tutorial = profile.Tutorial
	local publicBattle: any = false
	if type(battle) == "table" and battle.Consumed ~= true then
		publicBattle = {
			Id = battle.Id,
			MutantId = battle.MutantId,
			StartedAt = battle.StartedAt,
			EndsAt = battle.EndsAt,
			Reward = battle.Reward,
		}
	end

	local securedLoot = nil
	if type(profile.SecuredLoot) == "table" then
		securedLoot = {
			BioCoins = profile.SecuredLoot.BioCoins,
			DnaFragments = profile.SecuredLoot.DnaFragments,
			Items = deepCopy(profile.SecuredLoot.Items),
		}
	end

	return {
		BioCoins = profile.BioCoins,
		SlotsUnlocked = profile.SlotsUnlocked,
		Mutants = mutants,
		Tutorial = {
			Started = tutorial.Started,
			FreeBlobsClaimed = tutorial.FreeBlobsClaimed,
			FirstBlobCreated = tutorial.FirstBlobCreated,
			FirstMergeCompleted = tutorial.FirstMergeCompleted,
			FirstBattleStarted = tutorial.FirstBattleStarted,
			FirstBattleCompleted = tutorial.FirstBattleCompleted,
			FirstBlobPurchased = tutorial.FirstBlobPurchased,
			TutorialCompleted = tutorial.TutorialCompleted,
		},
		SecuredLoot = securedLoot,
		Battle = publicBattle,
		Revision = revision,
		PersistenceMode = mode,
	}
end

return GameState
