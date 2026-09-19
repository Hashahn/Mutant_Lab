--!strict

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

local function profile(coins: number)
	return {
		DataVersion = 1,
		BioCoins = coins,
		SlotsUnlocked = 6,
		Mutants = {},
		Tutorial = {},
	}
end

local function validate(value: any): boolean
	return type(value) == "table"
		and value.DataVersion == 1
		and type(value.BioCoins) == "number"
		and type(value.SlotsUnlocked) == "number"
		and type(value.Mutants) == "table"
		and type(value.Tutorial) == "table"
end

test("new profile is acquired with a lease and copied", function()
	local default = profile(100)
	local stored, code = ProfileStore.acquire(nil, "server-a", 1000, 120, default, validate)
	expect(code == "OK" and stored ~= nil, "acquire failed")
	expect(stored.Session.Token == "server-a", "wrong token")
	expect(stored.Session.LeaseUntil == 1120, "wrong lease")
	default.BioCoins = 999
	expect(stored.Profile.BioCoins == 100, "stored profile aliases default")
end)

test("an active foreign lock is rejected without replacing data", function()
	local current = {
		Profile = profile(75),
		Session = { Token = "server-a", LeaseUntil = 1120 },
	}
	local stored, code = ProfileStore.acquire(current, "server-b", 1050, 120, profile(100), validate)
	expect(stored == nil and code == "SESSION_LOCKED", "foreign lock was stolen")
	expect(current.Profile.BioCoins == 75, "current record was mutated")
end)

test("same token can recover an uncertain acquire", function()
	local current = {
		Profile = profile(75),
		Session = { Token = "server-a", LeaseUntil = 1120 },
	}
	local stored, code = ProfileStore.acquire(current, "server-a", 1050, 120, profile(100), validate)
	expect(code == "OK" and stored.Session.LeaseUntil == 1170, "same-token retry failed")
	expect(stored.Profile.BioCoins == 75, "retry replaced persisted profile")
end)

test("an expired lock can be taken over", function()
	local current = {
		Profile = profile(75),
		Session = { Token = "server-a", LeaseUntil = 1000 },
	}
	local stored, code = ProfileStore.acquire(current, "server-b", 1000, 120, profile(100), validate)
	expect(code == "OK" and stored.Session.Token == "server-b", "expired lock blocked takeover")
end)

test("stale and expired writers are rejected", function()
	local current = {
		Profile = profile(75),
		Session = { Token = "server-b", LeaseUntil = 1200 },
	}
	local stale, staleCode = ProfileStore.save(current, "server-a", profile(80), 1100, 120, false, validate)
	expect(stale == nil and staleCode == "SESSION_LOST", "stale writer saved")

	local expired, expiredCode =
		ProfileStore.save(current, "server-b", profile(80), 1200, 120, false, validate)
	expect(expired == nil and expiredCode == "SESSION_LOST", "expired writer saved")
end)

test("save copies the profile and release clears the lock", function()
	local current = {
		Profile = profile(75),
		Session = { Token = "server-a", LeaseUntil = 1200 },
	}
	local live = profile(90)
	local saved, saveCode = ProfileStore.save(current, "server-a", live, 1100, 120, false, validate)
	expect(saveCode == "OK" and saved.Session.LeaseUntil == 1220, "save did not renew")
	live.BioCoins = 999
	expect(saved.Profile.BioCoins == 90, "stored profile aliases live state")

	local released, releaseCode =
		ProfileStore.save(saved, "server-a", saved.Profile, 1110, 120, true, validate)
	expect(releaseCode == "OK" and released.Session == nil, "release retained lock")
end)

test("corrupt persisted data is never replaced by a default", function()
	local corrupt = { Profile = { DataVersion = 999 }, Session = nil }
	local stored, code = ProfileStore.acquire(corrupt, "server-a", 1000, 120, profile(100), validate)
	expect(stored == nil and code == "INVALID_DATA", "corrupt data became a new profile")
	expect(corrupt.Profile.DataVersion == 999, "corrupt record was mutated")
end)

test("non-finite leases and unknown lock fields are corrupt", function()
	for _, badSession in
		{
			{ Token = "server-a", LeaseUntil = 0 / 0 },
			{ Token = "server-a", LeaseUntil = math.huge },
			{ Token = "server-a", LeaseUntil = 1100, Unexpected = true },
		}
	do
		local stored, code = ProfileStore.acquire(
			{ Profile = profile(75), Session = badSession },
			"server-b",
			1200,
			120,
			profile(100),
			validate
		)
		expect(stored == nil and code == "INVALID_DATA", "malformed lease was accepted")
	end
end)

print(string.format("persistence.spec: %d tests passed", passed))
