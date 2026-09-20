--!strict

local GameConfig = require("../src/shared/Config/GameConfig")
local MutantConfig = require("../src/shared/Config/MutantConfig")
local GameState = require("../src/server/Domain/GameState")
local ProfileStore = require("../src/server/Domain/ProfileStore")

local passed = 0
local function test(name: string, run: () -> ())
	local ok, message = pcall(run)
	if not ok then
		error(name .. ": " .. tostring(message), 0)
	end
	passed += 1
end

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

-- Helper: create a valid v1 profile
local function createV1Profile(): any
	return {
		DataVersion = 1,
		BioCoins = 100,
		SlotsUnlocked = 6,
		Mutants = {
			{
				Id = "blob-1",
				Type = "Blob",
				Tier = 1,
				Level = 1,
			},
			{
				Id = "toxic-1",
				Type = "ToxicBlob",
				Tier = 2,
				Level = 1,
			},
		},
		Tutorial = {
			Started = true,
			FreeBlobsClaimed = 2,
			FirstBlobCreated = true,
			FirstMergeCompleted = true,
			FirstBattleStarted = true,
			FirstBattleCompleted = true,
			FirstBlobPurchased = true,
			TutorialCompleted = true,
		},
	}
end

test("v1 profile fails v2 validateProfile before migration", function()
	local v1 = createV1Profile()
	local ok = GameState.validateProfile(v1, GameConfig, MutantConfig)
	expect(not ok, "v1 profile should not validate directly against v2 config")
end)

test("migrateProfile correctly migrates v1 profile to v2", function()
	local v1 = createV1Profile()
	local migrated = GameState.migrateProfile(v1, GameConfig, MutantConfig)

	expect(migrated.DataVersion == 2, "DataVersion should be 2")
	expect(type(migrated.SecuredLoot) == "table", "SecuredLoot should be created")
	expect(migrated.SecuredLoot.BioCoins == 0, "SecuredLoot BioCoins should be 0")
	expect(migrated.SecuredLoot.DnaFragments == 0, "SecuredLoot DnaFragments should be 0")
	expect(type(migrated.SecuredLoot.Items) == "table", "SecuredLoot Items should be a table")

	-- Verify mutant 1 (Blob, Tier 1)
	local blob = migrated.Mutants[1]
	expect(blob.Role == "Striker", "Blob default role should be Striker")
	expect(type(blob.Genes) == "table", "Blob should have genes")
	expect(#blob.Genes == 3, "Tier 1 Blob should have 3 starter genes")
	expect(blob.Genes[1].Element == "Biomass" and blob.Genes[1].Value == 25, "Gene 1 should be Biomass 25")
	expect(blob.Genes[2].Element == "Plasma" and blob.Genes[2].Value == 20, "Gene 2 should be Plasma 20")
	expect(blob.Genes[3].Element == "Cryo" and blob.Genes[3].Value == 10, "Gene 3 should be Cryo 10")

	-- Verify mutant 2 (ToxicBlob, Tier 2)
	local toxic = migrated.Mutants[2]
	expect(toxic.Role == "Striker", "ToxicBlob default role should be Striker")
	expect(type(toxic.Genes) == "table", "ToxicBlob should have genes")
	expect(#toxic.Genes == 4, "Tier 2 ToxicBlob should have 4 starter genes")
	expect(toxic.Genes[1].Element == "Toxin" and toxic.Genes[1].Value == 50, "Gene 1 should be Toxin 50")
	expect(toxic.Genes[2].Element == "Biomass" and toxic.Genes[2].Value == 35, "Gene 2 should be Biomass 35")
	expect(toxic.Genes[3].Element == "Cryo" and toxic.Genes[3].Value == 25, "Gene 3 should be Cryo 25")
	expect(toxic.Genes[4].Element == "Shadow" and toxic.Genes[4].Value == 15, "Gene 4 should be Shadow 15")

	-- Verify migrated profile passes validation
	local valid = GameState.validateProfile(migrated, GameConfig, MutantConfig)
	expect(valid, "Migrated v2 profile must pass GameState.validateProfile")
end)

test("migrateProfile preserves existing custom genes and roles", function()
	local v1 = createV1Profile()
	v1.Mutants[1].Role = "Guardian"
	v1.Mutants[1].Genes = {
		{ Element = "Shadow", Value = 80 },
	}

	local migrated = GameState.migrateProfile(v1, GameConfig, MutantConfig)
	local m1 = migrated.Mutants[1]
	expect(m1.Role == "Guardian", "Existing role should be preserved")
	expect(#m1.Genes == 1, "Existing genes should not be overwritten")
	expect(m1.Genes[1].Element == "Shadow" and m1.Genes[1].Value == 80, "Gene values preserved")
end)

test("future data versions are not migrated and fail validation", function()
	local v3 = createV1Profile()
	v3.DataVersion = 3
	local migrated = GameState.migrateProfile(v3, GameConfig, MutantConfig)
	expect(migrated.DataVersion == 3, "Future version must not be touched")
	expect(
		not GameState.validateProfile(migrated, GameConfig, MutantConfig),
		"Future version must fail validation"
	)
end)

test("mutant gene validation rejects duplicates, invalid elements, and values > 100", function()
	local profile = GameState.newProfile(GameConfig)
	profile.Tutorial.Started = true
	profile.Tutorial.FreeBlobsClaimed = 1
	profile.Tutorial.FirstBlobCreated = true

	-- Duplicate gene element
	profile.Mutants = {
		{
			Id = "m1",
			Type = "Blob",
			Tier = 1,
			Level = 1,
			Role = "Striker",
			Genes = {
				{ Element = "Biomass", Value = 50 },
				{ Element = "Biomass", Value = 20 },
			},
		},
	}
	expect(
		not GameState.validateProfile(profile, GameConfig, MutantConfig),
		"Duplicate gene element must fail"
	)

	-- Value > 100
	profile.Mutants[1].Genes = {
		{ Element = "Biomass", Value = 101 },
	}
	expect(not GameState.validateProfile(profile, GameConfig, MutantConfig), "Gene value > 100 must fail")

	-- Value < 1
	profile.Mutants[1].Genes = {
		{ Element = "Biomass", Value = 0 },
	}
	expect(not GameState.validateProfile(profile, GameConfig, MutantConfig), "Gene value < 1 must fail")

	-- Invalid element
	profile.Mutants[1].Genes = {
		{ Element = "Fire", Value = 50 },
	}
	expect(not GameState.validateProfile(profile, GameConfig, MutantConfig), "Unknown element must fail")

	-- Too many genes for tier
	profile.Mutants[1].Genes = {
		{ Element = "Biomass", Value = 10 },
		{ Element = "Plasma", Value = 10 },
		{ Element = "Cryo", Value = 10 },
		{ Element = "Electro", Value = 10 }, -- 4th gene on Tier 1 (max 3)
	}
	expect(
		not GameState.validateProfile(profile, GameConfig, MutantConfig),
		"Too many gene slots for Tier 1 must fail"
	)

	-- Invalid role
	profile.Mutants[1].Genes = {
		{ Element = "Biomass", Value = 10 },
	}
	profile.Mutants[1].Role = "Sorcerer"
	expect(not GameState.validateProfile(profile, GameConfig, MutantConfig), "Unknown role must fail")
end)

test("ProfileStore.acquire migrates v1 envelope seamlessly", function()
	local v1 = createV1Profile()
	local currentEnvelope = {
		Profile = v1,
		Session = nil,
	}

	local defaultProfile = GameState.newProfile(GameConfig)
	local function validator(p: any): boolean
		return GameState.validateProfile(p, GameConfig, MutantConfig)
	end
	local function migrator(p: any): any
		return GameState.migrateProfile(p, GameConfig, MutantConfig)
	end

	local stored, code = ProfileStore.acquire(
		currentEnvelope,
		"session-test-token",
		1000,
		120,
		defaultProfile,
		validator,
		migrator
	)

	expect(code == "OK" and stored ~= nil, "acquire with migration failed")
	expect(stored.Profile.DataVersion == 2, "stored profile should be migrated to v2")
	expect(stored.Profile.SecuredLoot ~= nil, "SecuredLoot should be present")
	expect(stored.Session.Token == "session-test-token", "Session token should be acquired")
	expect(stored.Session.LeaseUntil == 1120, "Lease time should be 1120")
end)

print(string.format("PASS migration: %d tests", passed))
