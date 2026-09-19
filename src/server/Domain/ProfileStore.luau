--!strict

-- Pure stored-envelope transitions. Keeping these free of Roblox services makes
-- session-lock behavior testable without touching DataStore.
local ProfileStore = {}

local ENVELOPE_KEYS = { Profile = true, Session = true }
local SESSION_KEYS = { Token = true, LeaseUntil = true }

local function hasOnlyKeys(value: any, allowed: { [string]: boolean }): boolean
	for key in pairs(value) do
		if type(key) ~= "string" or not allowed[key] then
			return false
		end
	end
	return true
end

local function isFiniteInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
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

local function validEnvelope(value: any, validateProfile: (any) -> boolean): boolean
	if type(value) ~= "table" or type(value.Profile) ~= "table" then
		return false
	end
	if not hasOnlyKeys(value, ENVELOPE_KEYS) then
		return false
	end
	if not validateProfile(value.Profile) then
		return false
	end
	if value.Session == nil then
		return true
	end
	return type(value.Session) == "table"
		and hasOnlyKeys(value.Session, SESSION_KEYS)
		and type(value.Session.Token) == "string"
		and value.Session.Token ~= ""
		and isFiniteInteger(value.Session.LeaseUntil)
end

function ProfileStore.clone(value: any): any
	return deepCopy(value)
end

function ProfileStore.acquire(
	current: any,
	token: string,
	now: number,
	leaseSeconds: number,
	newProfile: any,
	validateProfile: (any) -> boolean
): (any?, string)
	local profile
	if current == nil then
		if not validateProfile(newProfile) then
			return nil, "INVALID_DEFAULT_PROFILE"
		end
		profile = deepCopy(newProfile)
	else
		if not validEnvelope(current, validateProfile) then
			return nil, "INVALID_DATA"
		end
		local lock = current.Session
		if lock ~= nil and lock.Token ~= token and lock.LeaseUntil > now then
			return nil, "SESSION_LOCKED"
		end
		profile = deepCopy(current.Profile)
	end

	return {
		Profile = profile,
		Session = {
			Token = token,
			LeaseUntil = now + leaseSeconds,
		},
	},
		"OK"
end

function ProfileStore.save(
	current: any,
	token: string,
	profile: any,
	now: number,
	leaseSeconds: number,
	release: boolean,
	validateProfile: (any) -> boolean
): (any?, string)
	if not validEnvelope(current, validateProfile) then
		return nil, "SESSION_LOST"
	end
	if not validateProfile(profile) then
		return nil, "INVALID_PROFILE"
	end

	local lock = current.Session
	if lock == nil or lock.Token ~= token or lock.LeaseUntil <= now then
		return nil, "SESSION_LOST"
	end

	return {
		Profile = deepCopy(profile),
		Session = if release
			then nil
			else {
				Token = token,
				LeaseUntil = now + leaseSeconds,
			},
	},
		"OK"
end

return ProfileStore
