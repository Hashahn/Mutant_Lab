local GameConfig = require("../src/shared/Config/GameConfig")
local MutantConfig = require("../src/shared/Config/MutantConfig")
local GameState = require("../src/server/Domain/GameState")
local GameRules = require("../src/server/Domain/GameRules")

local checks = 0
local function expect(condition, message)
	checks += 1
	assert(condition, message)
end

local function newRules()
	local nextId = 0
	return GameRules.new(GameConfig, MutantConfig, function()
		nextId += 1
		return "id-" .. tostring(nextId)
	end)
end

local function expectCode(ok, code, expected)
	expect(not ok, "operation unexpectedly succeeded")
	expect(code == expected, string.format("expected %s, got %s", expected, tostring(code)))
end

-- Profiles reject unknown/future/corrupt data instead of treating it as new data.
local initial = GameState.newProfile(GameConfig)
expect(initial.Tutorial.Started == false, "onboarding starts in the server session")
expect(GameState.validateProfile(initial, GameConfig, MutantConfig), "new profile must validate")

local future = GameState.newProfile(GameConfig)
future.DataVersion = GameConfig.DataVersion + 1
expect(not GameState.validateProfile(future, GameConfig, MutantConfig), "future data version accepted")
local unknownField = GameState.newProfile(GameConfig)
unknownField.SessionToken = "secret"
expect(
	not GameState.validateProfile(unknownField, GameConfig, MutantConfig),
	"unknown profile field accepted"
)
local invalidMoney = GameState.newProfile(GameConfig)
invalidMoney.BioCoins = 0 / 0
expect(not GameState.validateProfile(invalidMoney, GameConfig, MutantConfig), "NaN balance accepted")
local duplicateIds = GameState.newProfile(GameConfig)
duplicateIds.Mutants = {
	{ Id = "same", Type = "Blob", Tier = 1, Level = 1 },
	{ Id = "same", Type = "Blob", Tier = 1, Level = 1 },
}
expect(not GameState.validateProfile(duplicateIds, GameConfig, MutantConfig), "duplicate mutant IDs accepted")
local wrongSlots = GameState.newProfile(GameConfig)
wrongSlots.SlotsUnlocked += 1
expect(not GameState.validateProfile(wrongSlots, GameConfig, MutantConfig), "MVP slot upgrade accepted")
local freeWithoutProgress = GameState.newProfile(GameConfig)
freeWithoutProgress.Tutorial.FreeBlobsClaimed = 1
expect(
	not GameState.validateProfile(freeWithoutProgress, GameConfig, MutantConfig),
	"free count without progress accepted"
)
local emptyExhausted = GameState.newProfile(GameConfig)
emptyExhausted.Tutorial.Started = true
emptyExhausted.Tutorial.FreeBlobsClaimed = 2
emptyExhausted.Tutorial.FirstBlobCreated = true
expect(
	not GameState.validateProfile(emptyExhausted, GameConfig, MutantConfig),
	"empty progressed profile accepted"
)
local missingAcquisition = GameState.newProfile(GameConfig)
missingAcquisition.Tutorial.Started = true
missingAcquisition.Tutorial.FreeBlobsClaimed = 2
missingAcquisition.Tutorial.FirstBlobCreated = true
missingAcquisition.Mutants = { { Id = "one", Type = "Blob", Tier = 1, Level = 1 } }
expect(
	not GameState.validateProfile(missingAcquisition, GameConfig, MutantConfig),
	"unreachable free inventory accepted"
)
local prematureToxic = GameState.newProfile(GameConfig)
prematureToxic.Tutorial.Started = true
prematureToxic.Tutorial.FreeBlobsClaimed = 2
prematureToxic.Tutorial.FirstBlobCreated = true
prematureToxic.Mutants = { { Id = "toxic", Type = "ToxicBlob", Tier = 2, Level = 1 } }
expect(
	not GameState.validateProfile(prematureToxic, GameConfig, MutantConfig),
	"ToxicBlob without merge accepted"
)
local longId = GameState.newProfile(GameConfig)
longId.Tutorial.Started = true
longId.Tutorial.FreeBlobsClaimed = 1
longId.Tutorial.FirstBlobCreated = true
longId.Mutants = { { Id = string.rep("x", 65), Type = "Blob", Tier = 1, Level = 1 } }
expect(not GameState.validateProfile(longId, GameConfig, MutantConfig), "network-invalid mutant ID accepted")

-- The first two successful creates are free and persisted; later creates cost coins.
local rules = newRules()
local profile = GameState.newProfile(GameConfig)
local ok, code = rules:CreateBlob(profile, false)
expect(ok and code == "OK", "first free Blob failed")
expect(profile.BioCoins == GameConfig.StartingBioCoins, "first free Blob charged coins")
ok, code = rules:CreateBlob(profile, false)
expect(ok and code == "OK", "second free Blob failed")
expect(profile.Tutorial.FreeBlobsClaimed == 2, "free create count not persisted")
ok, code = rules:CreateBlob(profile, false)
expect(ok and code == "OK", "paid Blob failed")
expect(profile.BioCoins == 50 and profile.Tutorial.FirstBlobPurchased, "paid Blob price/tutorial state wrong")

local poor = GameState.newProfile(GameConfig)
poor.Tutorial.FreeBlobsClaimed = GameConfig.FreeTutorialBlobs
poor.BioCoins = GameConfig.BlobPrice - 1
ok, code = rules:CreateBlob(poor, false)
expectCode(ok, code, "INSUFFICIENT_FUNDS")
expect(#poor.Mutants == 0 and poor.BioCoins == GameConfig.BlobPrice - 1, "failed create mutated profile")

local full = GameState.newProfile(GameConfig)
full.SlotsUnlocked = 1
full.Mutants = { { Id = "only", Type = "Blob", Tier = 1, Level = 1 } }
ok, code = rules:CreateBlob(full, false)
expectCode(ok, code, "INVENTORY_FULL")

-- Merge consumes two distinct owned Blobs and creates one ToxicBlob.
local mergeProfile = GameState.newProfile(GameConfig)
local mergeRules = newRules()
mergeRules:CreateBlob(mergeProfile, false)
mergeRules:CreateBlob(mergeProfile, false)
ok, code = mergeRules:Merge(mergeProfile, false, "id-1", "id-1")
expectCode(ok, code, "INVALID_MERGE")
ok, code = mergeRules:Merge(mergeProfile, false, "id-1", "missing")
expectCode(ok, code, "MUTANT_NOT_FOUND")
ok, code = mergeRules:Merge(mergeProfile, false, "id-1", "id-2")
expect(ok and code == "OK", "valid merge failed")
expect(#mergeProfile.Mutants == 1 and mergeProfile.Mutants[1].Type == "ToxicBlob", "merge result wrong")
expect(mergeProfile.Tutorial.FirstMergeCompleted, "merge tutorial flag missing")
expect(GameState.validateProfile(mergeProfile, GameConfig, MutantConfig), "profile invalid after merge")

-- Battle is transient, enforces the tutorial order, and rewards exactly once.
local gatedProfile = GameState.newProfile(GameConfig)
local gatedRules = newRules()
gatedRules:CreateBlob(gatedProfile, false)
local battle
ok, code, battle = gatedRules:StartBattle(gatedProfile, false, "id-1", 10)
expectCode(ok, code, "TUTORIAL_REQUIRED")

local toxicId = mergeProfile.Mutants[1].Id
ok, code, battle = mergeRules:StartBattle(mergeProfile, false, toxicId, 100)
expect(ok and code == "OK" and type(battle) == "table", "battle did not start")
expect(battle.EndsAt == 106 and battle.Reward == 35 and not battle.Consumed, "battle record wrong")
local ok2, code2 = mergeRules:StartBattle(mergeProfile, battle, toxicId, 101)
expectCode(ok2, code2, "BATTLE_RUNNING")
ok2, code2 = mergeRules:CompleteBattle(mergeProfile, battle, 105.99)
expectCode(ok2, code2, "BATTLE_RUNNING")
local coinsBeforeReward = mergeProfile.BioCoins
local reward
ok, code, reward = mergeRules:CompleteBattle(mergeProfile, battle, 106)
expect(ok and code == "OK" and reward == 35, "battle completion reward wrong")
expect(mergeProfile.BioCoins == coinsBeforeReward + 35, "battle reward not applied")
expect(
	battle.Consumed and mergeProfile.Tutorial.TutorialCompleted,
	"completion guards/tutorial flags missing"
)
ok2, code2 = mergeRules:CompleteBattle(mergeProfile, battle, 200)
expectCode(ok2, code2, "INVALID_REQUEST")
expect(mergeProfile.BioCoins == coinsBeforeReward + 35, "duplicate completion rewarded twice")

-- Snapshot is a public deep copy and hides internal consumed state.
local activeBattle = {
	Id = "battle-public",
	MutantId = toxicId,
	StartedAt = 1,
	EndsAt = 7,
	Reward = 35,
	Consumed = false,
}
local snapshot = GameState.snapshot(mergeProfile, activeBattle, 9, "Memory")
expect(snapshot.Revision == 9 and snapshot.PersistenceMode == "Memory", "snapshot metadata wrong")
expect(snapshot.Battle ~= false and snapshot.Battle.Consumed == nil, "snapshot leaked internal battle state")
snapshot.Mutants[1].Type = "changed"
snapshot.Tutorial.TutorialCompleted = false
snapshot.Battle.Reward = 999
expect(mergeProfile.Mutants[1].Type == "ToxicBlob", "snapshot mutant aliases profile")
expect(mergeProfile.Tutorial.TutorialCompleted, "snapshot tutorial aliases profile")
expect(activeBattle.Reward == 35, "snapshot battle aliases transient record")
activeBattle.Consumed = true
expect(
	GameState.snapshot(mergeProfile, activeBattle, 10, "Memory").Battle == false,
	"consumed battle was published"
)

-- Busy mutants cannot merge/release; release has no refund and preserves one mutant.
local releaseRules = newRules()
local saturated = GameState.newProfile(GameConfig)
saturated.Tutorial.Started = true
saturated.Tutorial.FreeBlobsClaimed = 2
saturated.Tutorial.FirstBlobCreated = true
saturated.Tutorial.FirstMergeCompleted = true
saturated.Tutorial.FirstBattleStarted = true
saturated.Tutorial.FirstBattleCompleted = true
saturated.Tutorial.TutorialCompleted = true
for index = 1, saturated.SlotsUnlocked do
	table.insert(saturated.Mutants, {
		Id = "toxic-" .. tostring(index),
		Type = "ToxicBlob",
		Tier = 2,
		Level = 1,
	})
end
local balanceBeforeRelease = saturated.BioCoins
ok, code = releaseRules:ReleaseMutant(saturated, false, "toxic-1")
expect(
	ok and code == "OK" and #saturated.Mutants == saturated.SlotsUnlocked - 1,
	"saturated tier-2 recovery failed"
)
expect(saturated.BioCoins == balanceBeforeRelease, "release refunded coins")

local releaseBattle
ok, code, releaseBattle = releaseRules:StartBattle(saturated, false, "toxic-2", 0)
expect(ok, "release test battle failed to start")
ok2, code2 = releaseRules:ReleaseMutant(saturated, releaseBattle, "toxic-2")
expectCode(ok2, code2, "MUTANT_BUSY")

local last = GameState.newProfile(GameConfig)
last.Tutorial.TutorialCompleted = true
last.Mutants = { { Id = "last", Type = "Blob", Tier = 1, Level = 1 } }
ok, code = releaseRules:ReleaseMutant(last, false, "last")
expectCode(ok, code, "LAST_MUTANT")

local beforeTutorial = GameState.newProfile(GameConfig)
beforeTutorial.Mutants =
	{ { Id = "one", Type = "Blob", Tier = 1, Level = 1 }, { Id = "two", Type = "Blob", Tier = 1, Level = 1 } }
ok, code = releaseRules:ReleaseMutant(beforeTutorial, false, "one")
expectCode(ok, code, "TUTORIAL_REQUIRED")

local busyMerge = GameState.newProfile(GameConfig)
local busyRules = newRules()
busyRules:CreateBlob(busyMerge, false)
busyRules:CreateBlob(busyMerge, false)
busyMerge.Tutorial.FirstMergeCompleted = true
busyMerge.Tutorial.TutorialCompleted = true
local blobBattle
ok, code, blobBattle = busyRules:StartBattle(busyMerge, false, "id-1", 0)
expect(ok, "busy merge battle failed to start")
ok, code = busyRules:Merge(busyMerge, blobBattle, "id-1", "id-2")
expectCode(ok, code, "MUTANT_BUSY")
expect(#busyMerge.Mutants == 2, "busy merge mutated inventory")

print(string.format("PASS domain: %d checks", checks))
