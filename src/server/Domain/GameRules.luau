--!strict

local GameRules = {}
GameRules.__index = GameRules

local MAX_ID_ATTEMPTS = 32

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function findMutant(profile: any, mutantId: any): (number?, any?)
	if type(mutantId) ~= "string" then
		return nil, nil
	end
	for index, mutant in ipairs(profile.Mutants) do
		if mutant.Id == mutantId then
			return index, mutant
		end
	end
	return nil, nil
end

local function isActiveBattle(battle: any): boolean
	return type(battle) == "table" and battle.Consumed ~= true
end

function GameRules.new(gameConfig: any, mutantConfig: any, makeId: () -> string): any
	return setmetatable({
		_gameConfig = gameConfig,
		_mutantConfig = mutantConfig,
		_makeId = makeId,
		_battleSequence = 0,
	}, GameRules)
end

function GameRules:_candidateId(): string?
	local ok, result = pcall(self._makeId)
	if not ok or type(result) ~= "string" or #result < 1 or #result > 64 then
		return nil
	end
	return result
end

function GameRules:_newMutantId(profile: any): string?
	for _ = 1, MAX_ID_ATTEMPTS do
		local candidate = self:_candidateId()
		if candidate == nil then
			return nil
		end
		local exists = findMutant(profile, candidate)
		if exists == nil then
			return candidate
		end
	end
	return nil
end

function GameRules:_newBattleId(): string?
	local candidate = self:_candidateId()
	if candidate == nil then
		return nil
	end

	-- A shared GameRules instance serves every player. A sequence suffix guarantees
	-- session-process uniqueness without retaining every historical battle ID.
	self._battleSequence += 1
	local suffix = "-" .. tostring(self._battleSequence)
	local prefixLength = 64 - #suffix
	if prefixLength < 1 then
		return nil
	end
	return string.sub(candidate, 1, prefixLength) .. suffix
end

function GameRules:CreateBlob(profile: any, _battle: any): (boolean, string)
	if #profile.Mutants >= profile.SlotsUnlocked then
		return false, "INVENTORY_FULL"
	end

	local tutorial = profile.Tutorial
	local isFree = tutorial.FreeBlobsClaimed < self._gameConfig.FreeTutorialBlobs
	if not isFree and profile.BioCoins < self._gameConfig.BlobPrice then
		return false, "INSUFFICIENT_FUNDS"
	end

	local mutantId = self:_newMutantId(profile)
	local definition = self._mutantConfig.Blob
	if mutantId == nil or type(definition) ~= "table" then
		return false, "INTERNAL_ERROR"
	end

	if isFree then
		tutorial.FreeBlobsClaimed += 1
	else
		profile.BioCoins -= self._gameConfig.BlobPrice
		tutorial.FirstBlobPurchased = true
	end
	tutorial.Started = true
	tutorial.FirstBlobCreated = true
	table.insert(profile.Mutants, {
		Id = mutantId,
		Type = "Blob",
		Tier = definition.Tier,
		Level = 1,
	})

	return true, "OK"
end

function GameRules:Merge(profile: any, battle: any, firstId: any, secondId: any): (boolean, string)
	if type(firstId) ~= "string" or type(secondId) ~= "string" or firstId == secondId then
		return false, "INVALID_MERGE"
	end

	local firstIndex, first = findMutant(profile, firstId)
	local secondIndex, second = findMutant(profile, secondId)
	if firstIndex == nil or secondIndex == nil then
		return false, "MUTANT_NOT_FOUND"
	end
	if isActiveBattle(battle) and (battle.MutantId == firstId or battle.MutantId == secondId) then
		return false, "MUTANT_BUSY"
	end
	if first.Type ~= "Blob" or second.Type ~= "Blob" then
		return false, "INVALID_MERGE"
	end

	local definition = self._mutantConfig.ToxicBlob
	local mutantId = self:_newMutantId(profile)
	if type(definition) ~= "table" or mutantId == nil then
		return false, "INTERNAL_ERROR"
	end

	local highIndex = math.max(firstIndex, secondIndex)
	local lowIndex = math.min(firstIndex, secondIndex)
	table.remove(profile.Mutants, highIndex)
	table.remove(profile.Mutants, lowIndex)
	table.insert(profile.Mutants, {
		Id = mutantId,
		Type = "ToxicBlob",
		Tier = definition.Tier,
		Level = 1,
	})
	profile.Tutorial.FirstMergeCompleted = true

	return true, "OK"
end

function GameRules:StartBattle(profile: any, battle: any, mutantId: any, now: any): (boolean, string, any?)
	if isActiveBattle(battle) then
		return false, "BATTLE_RUNNING", nil
	end
	if not profile.Tutorial.FirstMergeCompleted then
		return false, "TUTORIAL_REQUIRED", nil
	end
	if not isFiniteNumber(now) then
		return false, "INVALID_REQUEST", nil
	end

	local _, mutant = findMutant(profile, mutantId)
	if mutant == nil then
		return false, "MUTANT_NOT_FOUND", nil
	end
	if not profile.Tutorial.TutorialCompleted and mutant.Type ~= "ToxicBlob" then
		return false, "TUTORIAL_REQUIRED", nil
	end
	local definition = self._mutantConfig[mutant.Type]
	if type(definition) ~= "table" or not isFiniteNumber(definition.BattleReward) then
		return false, "INTERNAL_ERROR", nil
	end

	local battleId = self:_newBattleId()
	if battleId == nil then
		return false, "INTERNAL_ERROR", nil
	end

	local record = {
		Id = battleId,
		MutantId = mutant.Id,
		StartedAt = now,
		EndsAt = now + self._gameConfig.BattleDuration,
		Reward = definition.BattleReward,
		Consumed = false,
	}
	profile.Tutorial.FirstBattleStarted = true

	return true, "OK", record
end

-- On success this marks battle.Consumed before returning. The session owner must
-- replace the battle with false before publishing its next snapshot. Keeping the
-- consumed record until that point makes duplicate completion calls harmless.
function GameRules:CompleteBattle(profile: any, battle: any, now: any): (boolean, string, number?)
	if type(battle) ~= "table" or battle.Consumed == true then
		return false, "INVALID_REQUEST", nil
	end
	if not isFiniteNumber(now) then
		return false, "INVALID_REQUEST", nil
	end
	if now < battle.EndsAt then
		return false, "BATTLE_RUNNING", nil
	end

	local _, mutant = findMutant(profile, battle.MutantId)
	if mutant == nil then
		return false, "MUTANT_NOT_FOUND", nil
	end
	local definition = self._mutantConfig[mutant.Type]
	if type(definition) ~= "table" or battle.Reward ~= definition.BattleReward then
		return false, "INTERNAL_ERROR", nil
	end

	local available = math.max(0, self._gameConfig.MaxBioCoins - profile.BioCoins)
	local reward = math.min(definition.BattleReward, available)

	battle.Consumed = true
	profile.BioCoins += reward
	profile.Tutorial.FirstBattleCompleted = true
	if mutant.Type == "ToxicBlob" then
		profile.Tutorial.TutorialCompleted = true
	end

	return true, "OK", reward
end

function GameRules:ReleaseMutant(profile: any, battle: any, mutantId: any): (boolean, string)
	if not profile.Tutorial.TutorialCompleted then
		return false, "TUTORIAL_REQUIRED"
	end

	local index = findMutant(profile, mutantId)
	if index == nil then
		return false, "MUTANT_NOT_FOUND"
	end
	if isActiveBattle(battle) and battle.MutantId == mutantId then
		return false, "MUTANT_BUSY"
	end
	if #profile.Mutants <= 1 then
		return false, "LAST_MUTANT"
	end

	table.remove(profile.Mutants, index)
	return true, "OK"
end

return GameRules
