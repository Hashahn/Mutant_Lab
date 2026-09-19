--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local GameState = require("../src/server/Domain/GameState")
local GameConfig = require("../src/shared/Config/GameConfig")
local MutantConfig = require("../src/shared/Config/MutantConfig")
local ProfileStore = require("../src/server/Domain/ProfileStore")

local source = fs.readFile("src/server/Services/PlayerDataService.luau")
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

local function newScheduler()
	local queued = {}
	local taskMock = {}

	local function makeThread(callback, ...)
		local arguments = table.pack(...)
		return coroutine.create(function()
			callback(table.unpack(arguments, 1, arguments.n))
		end)
	end

	function taskMock.spawn(callback, ...)
		local thread = makeThread(callback, ...)
		table.insert(queued, thread)
		return thread
	end

	function taskMock.defer(callback, ...)
		return taskMock.spawn(callback, ...)
	end

	function taskMock.wait(_seconds)
		return coroutine.yield("WAIT")
	end

	return {
		task = taskMock,
		queued = queued,
		resume = function(thread)
			local ok, first, second = coroutine.resume(thread)
			if not ok then
				error(first, 2)
			end
			return coroutine.status(thread), first, second
		end,
		pop = function()
			return table.remove(queued, 1)
		end,
	}
end

local function newHarness(options: any?)
	options = options or {}
	local scheduler = newScheduler()
	local record = options.record
	local calls = 0
	local warnings = {}
	local tokenIndex = 0

	local store = {}
	function store:UpdateAsync(_key, transform)
		calls += 1
		if options.failUpdates then
			error("simulated datastore outage")
		end
		local nextValue = transform(record)
		if nextValue ~= nil then
			record = ProfileStore.clone(nextValue)
		end
		if options.yieldCalls and options.yieldCalls[calls] then
			coroutine.yield("DATASTORE")
		end
		return if nextValue == nil then nil else ProfileStore.clone(nextValue)
	end

	local dataStoreService = {}
	function dataStoreService:GetDataStore(_name, _scope)
		return store
	end
	local httpService = {}
	function httpService:GenerateGUID(_braces)
		tokenIndex += 1
		return "token-" .. tostring(tokenIndex)
	end
	local runService = {}
	function runService:IsStudio()
		return true
	end

	local config = {
		DataStoreName = "TestProfiles",
		LiveNamespace = "live-test",
		StudioNamespace = "studio-test",
		KeyPrefix = "player:",
		SessionLeaseSeconds = 120,
		RenewIntervalSeconds = 30,
		AutosaveIntervalSeconds = 60,
		RetryAttempts = options.retryAttempts or 1,
		RetryBaseDelaySeconds = 0,
		ShutdownTimeoutSeconds = 5,
		StudioPersistence = {
			Enabled = options.enabled ~= false,
			UniverseId = options.universeId or 123,
		},
	}
	local configModule = {}
	local profileStoreModule = {}
	local fakeGame = { GameId = options.gameId or 123 }
	function fakeGame:GetService(name)
		if name == "DataStoreService" then
			return dataStoreService
		elseif name == "HttpService" then
			return httpService
		elseif name == "RunService" then
			return runService
		end
		error("unexpected service " .. tostring(name))
	end

	local environment = {
		game = fakeGame,
		script = {
			Parent = {
				Parent = {
					Config = { PersistenceConfig = configModule },
					Domain = { ProfileStore = profileStoreModule },
				},
			},
		},
		task = scheduler.task,
		warn = function(message)
			table.insert(warnings, tostring(message))
		end,
		require = function(module)
			if module == configModule then
				return config
			elseif module == profileStoreModule then
				return ProfileStore
			end
			error("unexpected module")
		end,
	}
	local chunk = luau.load(source, {
		debugName = "PlayerDataService.luau",
		environment = environment,
		injectGlobals = true,
	})
	local PlayerDataService = chunk()

	return {
		serviceModule = PlayerDataService,
		scheduler = scheduler,
		warnings = warnings,
		calls = function()
			return calls
		end,
		record = function()
			return record
		end,
	}
end

local function player(userId: number)
	return {
		UserId = userId,
		Parent = true,
		Kicked = false,
		Kick = function(self)
			self.Kicked = true
		end,
	}
end

test("enabled Studio persistence rejects the wrong universe", function()
	local harness = newHarness({ universeId = 999, gameId = 123 })
	local ok = pcall(function()
		harness.serviceModule.new(GameConfig, MutantConfig, GameState)
	end)
	expect(not ok, "wrong Studio universe silently fell back")
	expect(harness.calls() == 0, "wrong universe touched DataStore")
end)

test("failed load is never followed by a default save", function()
	local harness = newHarness({ failUpdates = true })
	local service = harness.serviceModule.new(GameConfig, MutantConfig, GameState)
	local subject = player(10)
	local loaded, code = service:Load(subject)
	expect(loaded == nil and code == "DATASTORE_ERROR", "failed load opened a profile")
	expect(harness.calls() == 1, "load retried beyond configured bound")
	expect(service:Get(subject) == nil, "failed profile remained usable")
	service:Remove(subject)
	expect(harness.calls() == 1, "Remove saved a default after failed load")
	expect(#harness.warnings == 1, "final UpdateAsync failure was not diagnosed")
end)

test("leave during load releases the acquired lock before returning", function()
	local harness = newHarness({ yieldCalls = { [1] = true } })
	local service = harness.serviceModule.new(GameConfig, MutantConfig, GameState)
	local subject = player(11)
	local loaded, code
	local loadThread = coroutine.create(function()
		loaded, code = service:Load(subject)
	end)
	local status, reason = harness.scheduler.resume(loadThread)
	expect(status == "suspended" and reason == "DATASTORE", "load did not pause in UpdateAsync")
	expect(service:Remove(subject) == false, "loading removal reported a synchronous release")
	status = harness.scheduler.resume(loadThread)
	expect(status == "dead", "load did not finish after DataStore resumed")
	expect(loaded == nil and code == "PLAYER_LEFT", "departed player received a profile")
	expect(harness.calls() == 2, "acquired lock was not released")
	expect(harness.record().Session == nil, "leave during load retained its lock")
	expect(service:Get(subject) == nil, "departed profile remained usable")
end)

test("close waits for an in-flight save then releases exactly once", function()
	local harness = newHarness({ yieldCalls = { [2] = true } })
	local service = harness.serviceModule.new(GameConfig, MutantConfig, GameState)
	local subject = player(12)
	local profileValue, loadCode = service:Load(subject)
	expect(profileValue ~= nil and loadCode == "OK", "setup load failed")
	profileValue.BioCoins = 77

	local saveResult
	local saveThread = coroutine.create(function()
		saveResult = service:Save(subject, false)
	end)
	local saveStatus, saveReason = harness.scheduler.resume(saveThread)
	expect(saveStatus == "suspended" and saveReason == "DATASTORE", "save did not pause")

	local closeResult
	local closeThread = coroutine.create(function()
		closeResult = service:Close()
	end)
	local closeStatus = harness.scheduler.resume(closeThread)
	expect(closeStatus == "suspended", "Close did not wait for shutdown work")

	local releaseThread = harness.scheduler.pop()
	expect(releaseThread ~= nil, "Close did not schedule release")
	local releaseStatus = harness.scheduler.resume(releaseThread)
	expect(releaseStatus == "suspended", "release did not serialize behind save")

	saveStatus = harness.scheduler.resume(saveThread)
	expect(saveStatus == "dead" and saveResult == true, "in-flight save failed")
	releaseStatus = harness.scheduler.resume(releaseThread)
	expect(releaseStatus == "dead", "release did not finish after save")
	closeStatus = harness.scheduler.resume(closeThread)
	expect(closeStatus == "dead" and closeResult == true, "Close did not finish cleanly")
	expect(harness.calls() == 3, "unexpected duplicate persistence operation")
	expect(harness.record().Profile.BioCoins == 77, "release lost the in-flight save")
	expect(harness.record().Session == nil, "Close retained the session lock")
end)

print(string.format("persistence-lifecycle.spec: %d tests passed", passed))
