--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PersistenceConfig = require(script.Parent.Parent.Config.PersistenceConfig)
local ProfileStore = require(script.Parent.Parent.Domain.ProfileStore)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local MemoryStore = {}
MemoryStore.__index = MemoryStore

function MemoryStore.new()
	return setmetatable({ Values = {} }, MemoryStore)
end

function MemoryStore:UpdateAsync(key: string, transform: (any) -> any): any
	local nextValue = transform(self.Values[key])
	if nextValue ~= nil then
		self.Values[key] = ProfileStore.clone(nextValue)
	end
	return if nextValue == nil then nil else ProfileStore.clone(nextValue)
end

local function deepFreeze(value: any, seen: { [any]: boolean }?)
	if type(value) ~= "table" or table.isfrozen(value) then
		return
	end
	local visited = seen or {}
	if visited[value] then
		return
	end
	visited[value] = true
	for key, child in pairs(value) do
		deepFreeze(key, visited)
		deepFreeze(child, visited)
	end
	table.freeze(value)
end

local function countEntries(values: { [any]: any }): number
	local count = 0
	for _ in pairs(values) do
		count += 1
	end
	return count
end

function PlayerDataService.new(gameConfig: any, mutantConfig: any, gameState: any)
	assert(type(gameState) == "table", "gameState is required")
	assert(type(gameState.newProfile) == "function", "gameState.newProfile is required")
	assert(type(gameState.validateProfile) == "function", "gameState.validateProfile is required")

	local mode: string
	local store: any
	if RunService:IsStudio() then
		local studio = PersistenceConfig.StudioPersistence
		if studio.Enabled then
			assert(
				studio.UniverseId > 0 and game.GameId == studio.UniverseId,
				"Studio persistence requires the configured dedicated test universe"
			)
			mode = "STUDIO_DATASTORE"
			store = DataStoreService:GetDataStore(
				PersistenceConfig.DataStoreName,
				PersistenceConfig.StudioNamespace
			)
		else
			mode = "MEMORY"
			store = MemoryStore.new()
		end
	else
		mode = "LIVE_DATASTORE"
		store =
			DataStoreService:GetDataStore(PersistenceConfig.DataStoreName, PersistenceConfig.LiveNamespace)
	end

	local self = setmetatable({
		Mode = mode,
		GameConfig = gameConfig,
		MutantConfig = mutantConfig,
		GameState = gameState,
		Store = store,
		Sessions = {},
		Started = false,
		Closing = false,
	}, PlayerDataService)
	return self
end

function PlayerDataService:_validate(profile: any): boolean
	return self.GameState.validateProfile(profile, self.GameConfig, self.MutantConfig) == true
end

function PlayerDataService:_migrate(profile: any): any
	if type(self.GameState.migrateProfile) == "function" then
		return self.GameState.migrateProfile(profile, self.GameConfig, self.MutantConfig)
	end
	return profile
end

function PlayerDataService:_key(player: Player): string
	return PersistenceConfig.KeyPrefix .. tostring(player.UserId)
end

function PlayerDataService:_update(key: string, transform: (any) -> (any?, string)): (any?, string)
	local lastError = "DATASTORE_ERROR"
	for attempt = 1, PersistenceConfig.RetryAttempts do
		local callbackCode = "UPDATE_ABORTED"
		local ok, result = pcall(function()
			return self.Store:UpdateAsync(key, function(current: any)
				local nextValue, code = transform(current)
				callbackCode = code
				return nextValue
			end)
		end)
		if ok then
			return result, callbackCode
		end

		lastError = "DATASTORE_ERROR"
		if attempt < PersistenceConfig.RetryAttempts then
			task.wait(PersistenceConfig.RetryBaseDelaySeconds * (2 ^ (attempt - 1)))
		end
	end
	warn(
		string.format(
			"[MutantLab Persistence] UpdateAsync failed in %s mode after %d attempts",
			self.Mode,
			PersistenceConfig.RetryAttempts
		)
	)
	return nil, lastError
end

function PlayerDataService:_lose(player: Player, state: any, code: string)
	if state.Lost then
		return
	end
	state.Lost = true
	state.Phase = "Lost"
	state.LastError = code
	if state.Profile ~= nil then
		deepFreeze(state.Profile)
	end
	state.Profile = nil

	-- Get remains non-yielding; removal from the server is deferred.
	task.defer(function()
		pcall(function()
			player:Kick("Your data session is no longer safe (" .. code .. "). Please reconnect.")
		end)
	end)
end

function PlayerDataService:_acquireBusy(state: any, deadline: number?): boolean
	while state.Busy do
		if deadline ~= nil and os.clock() >= deadline then
			return false
		end
		task.wait()
	end
	state.Busy = true
	return true
end

function PlayerDataService:Load(player: Player): (any?, string)
	if self.Closing then
		return nil, "SERVICE_CLOSED"
	end

	local existing = self.Sessions[player]
	if existing ~= nil then
		local profile = self:Get(player)
		return profile, if profile ~= nil then "OK" else "ALREADY_LOADING"
	end

	local state = {
		Token = HttpService:GenerateGUID(false),
		Phase = "Loading",
		Busy = true,
		Removing = false,
		Lost = false,
		Profile = nil,
		LeaseUntil = 0,
		LastSaveAttempt = os.clock(),
		LastError = nil,
	}
	self.Sessions[player] = state

	-- Construct and copy the default before the first yielding persistence call.
	local defaultProfile = ProfileStore.clone(self.GameState.newProfile(self.GameConfig))
	if not self:_validate(defaultProfile) then
		state.Busy = false
		self.Sessions[player] = nil
		return nil, "INVALID_DEFAULT_PROFILE"
	end

	local stored, code = self:_update(self:_key(player), function(current: any)
		return ProfileStore.acquire(
			current,
			state.Token,
			os.time(),
			PersistenceConfig.SessionLeaseSeconds,
			defaultProfile,
			function(profile: any): boolean
				return self:_validate(profile)
			end,
			function(profile: any): any
				return self:_migrate(profile)
			end
		)
	end)

	if stored == nil or code ~= "OK" then
		state.Busy = false
		state.LastError = code
		if self.Sessions[player] == state then
			self.Sessions[player] = nil
		end
		return nil, code
	end

	state.Profile = ProfileStore.clone(stored.Profile)
	state.LeaseUntil = stored.Session.LeaseUntil
	state.Phase = "Active"
	state.Busy = false
	state.LastSaveAttempt = os.clock()

	-- PlayerRemoving may run while UpdateAsync is yielding. In that case never
	-- expose the loaded profile; immediately save/release the lock we acquired.
	if state.Removing or self.Closing then
		self:_saveState(player, state, true, true, nil)
		if self.Sessions[player] == state then
			self.Sessions[player] = nil
		end
		return nil, "PLAYER_LEFT"
	end

	return state.Profile, "OK"
end

function PlayerDataService:Get(player: Player): any?
	local state = self.Sessions[player]
	if self.Closing or state == nil or state.Phase ~= "Active" or state.Removing or state.Lost then
		return nil
	end
	if state.LeaseUntil <= os.time() then
		self:_lose(player, state, "SESSION_EXPIRED")
		return nil
	end
	return state.Profile
end

function PlayerDataService:_saveState(
	player: Player,
	state: any,
	release: boolean,
	allowRemoving: boolean,
	deadline: number?
): boolean
	if state.Lost or state.Phase ~= "Active" or (state.Removing and not allowRemoving) then
		return false
	end
	if state.LeaseUntil <= os.time() then
		self:_lose(player, state, "SESSION_EXPIRED")
		return false
	end
	if not self:_acquireBusy(state, deadline) then
		return false
	end

	if state.Lost or state.Phase ~= "Active" or (state.Removing and not allowRemoving) then
		state.Busy = false
		return false
	end

	-- The live profile is never captured by an operation that yields.
	local profile = ProfileStore.clone(state.Profile)
	if not self:_validate(profile) then
		state.Busy = false
		self:_lose(player, state, "INVALID_PROFILE")
		return false
	end

	state.LastSaveAttempt = os.clock()
	local stored, code = self:_update(self:_key(player), function(current: any)
		return ProfileStore.save(
			current,
			state.Token,
			profile,
			os.time(),
			PersistenceConfig.SessionLeaseSeconds,
			release,
			function(candidate: any): boolean
				return self:_validate(candidate)
			end,
			function(candidate: any): any
				return self:_migrate(candidate)
			end
		)
	end)

	state.Busy = false
	if stored == nil or code ~= "OK" then
		state.LastError = code
		if not release then
			-- A failed UpdateAsync is an uncertain renewal: this server must stop
			-- serving mutations even if the prior lease has time remaining.
			self:_lose(player, state, code)
		end
		return false
	end

	if release then
		state.Phase = "Released"
		state.Profile = nil
		state.LeaseUntil = 0
	else
		state.LeaseUntil = stored.Session.LeaseUntil
	end
	state.LastError = nil
	return true
end

function PlayerDataService:Save(player: Player, release: boolean?): boolean
	local state = self.Sessions[player]
	if self.Closing or state == nil then
		return false
	end
	return self:_saveState(player, state, release == true, false, nil)
end

function PlayerDataService:Remove(player: Player): boolean
	local state = self.Sessions[player]
	if state == nil then
		return true
	end
	if state.Removing then
		return false
	end

	state.Removing = true
	if state.Phase == "Loading" then
		-- Load observes Removing after its yield and performs the release.
		return false
	end

	local released = self:_saveState(player, state, true, true, nil)
	if not released then
		warn("[MutantLab Persistence] profile release failed during player removal")
	end
	if self.Sessions[player] == state then
		self.Sessions[player] = nil
	end
	return released
end

function PlayerDataService:Start()
	if self.Started then
		return
	end
	self.Started = true

	local interval =
		math.min(PersistenceConfig.AutosaveIntervalSeconds, PersistenceConfig.RenewIntervalSeconds)
	task.spawn(function()
		while self.Started and not self.Closing do
			task.wait(math.min(interval, 1))
			local now = os.clock()
			for player, state in pairs(self.Sessions) do
				if
					state.Phase == "Active"
					and not state.Removing
					and not state.Lost
					and not state.Busy
					and now - state.LastSaveAttempt >= interval
				then
					state.LastSaveAttempt = now
					task.spawn(function()
						self:Save(player, false)
					end)
				end
			end
		end
	end)
end

function PlayerDataService:Close(): boolean
	if self.Closing then
		return countEntries(self.Sessions) == 0
	end
	self.Closing = true
	self.Started = false

	local deadline = os.clock() + PersistenceConfig.ShutdownTimeoutSeconds
	for player, state in pairs(self.Sessions) do
		if not state.Removing then
			state.Removing = true
			if state.Phase ~= "Loading" then
				task.spawn(function()
					local released = self:_saveState(player, state, true, true, deadline)
					if not released then
						warn("[MutantLab Persistence] profile release failed during shutdown")
					end
					if self.Sessions[player] == state then
						self.Sessions[player] = nil
					end
				end)
			end
		end
	end

	while countEntries(self.Sessions) > 0 and os.clock() < deadline do
		task.wait()
	end
	return countEntries(self.Sessions) == 0
end

return PlayerDataService
