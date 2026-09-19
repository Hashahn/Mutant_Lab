--!strict

local GameState = {}

local PROFILE_KEYS = {
	DataVersion = true,
	BioCoins = true,
	SlotsUnlocked = true,
	Mutants = true,
	Tutorial = true,
}

local MUTANT_KEYS = {
	Id = true,
	Type = true,
	Tier = true,
	Level = true,
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
	}
end

function GameState.validateProfile(profile: any, gameConfig: any, mutantConfig: any): boolean
	if not hasExactKeys(profile, PROFILE_KEYS) then
		return false
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

	local ids = {}
	local acquisitionUnits = 0
	local hasToxicBlob = false
	for _, mutant in ipairs(profile.Mutants) do
		if not hasExactKeys(mutant, MUTANT_KEYS) then
			return false
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
			or mutant.Level ~= 1
		then
			return false
		end
		if mutant.Type == "Blob" then
			acquisitionUnits += 1
		elseif mutant.Type == "ToxicBlob" then
			acquisitionUnits += 2
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
	if tutorial.FirstBattleStarted and not tutorial.FirstMergeCompleted then
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
	if not tutorial.FirstMergeCompleted and hasToxicBlob then
		return false
	end

	-- Merging preserves acquired tier-1 units: Blob counts as one and
	-- ToxicBlob as two. Without a paid Blob, this must equal the persisted
	-- free-create count. Paid profiles may shrink only after release unlocks.
	if not tutorial.FirstBlobPurchased and acquisitionUnits ~= tutorial.FreeBlobsClaimed then
		return false
	end
	if
		tutorial.FirstBlobPurchased
		and not tutorial.TutorialCompleted
		and acquisitionUnits < tutorial.FreeBlobsClaimed + 1
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
		Battle = publicBattle,
		Revision = revision,
		PersistenceMode = mode,
	}
end

return GameState
