--!strict
local RunService = nil
if typeof(game) == "Instance" or typeof(game) == "table" then
	pcall(function()
		RunService = (game :: any):GetService("RunService")
	end)
end

local RequestValidator = {}
local function validId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end
function RequestValidator.isValid(action: any, payload: any): boolean
	if type(action) ~= "string" then
		return false
	end
	if RunService and RunService:IsStudio() and action == "DebugSetupSquad" then
		return true
	end
	if action == "CreateBlob" then
		return payload == nil
	end
	if action == "SecureLoot" or action == "Evacuate" or action == "ProceedNextRoom" then
		return payload == nil or (type(payload) == "table" and next(payload) == nil)
	end
	if type(payload) ~= "table" then
		return false
	end

	if action == "StartExpedition" then
		if payload.RoomCount ~= 3 and payload.RoomCount ~= 5 then
			return false
		end
		if type(payload.ActiveIds) ~= "table" or #payload.ActiveIds < 1 or #payload.ActiveIds > 3 then
			return false
		end
		local seenIds = {}
		for _, id in payload.ActiveIds do
			if not validId(id) or seenIds[id] then
				return false
			end
			seenIds[id] = true
		end
		if payload.ReserveIds ~= nil then
			if type(payload.ReserveIds) ~= "table" or #payload.ReserveIds > 3 then
				return false
			end
			for _, id in payload.ReserveIds do
				if not validId(id) or seenIds[id] then
					return false
				end
				seenIds[id] = true
			end
		end
		-- Check no unexpected extra fields
		for k in payload do
			if k ~= "RoomCount" and k ~= "ActiveIds" and k ~= "ReserveIds" then
				return false
			end
		end
		return true
	end

	if action == "SelectCombatAction" then
		local validAbilities = { Basic = true, RoleSkill = true, Ultimate = true }
		if type(payload.AbilityType) ~= "string" or not validAbilities[payload.AbilityType] then
			return false
		end
		if payload.TargetId ~= nil and not validId(payload.TargetId) then
			return false
		end
		if payload.ActorId ~= nil and not validId(payload.ActorId) then
			return false
		end
		for k in payload do
			if k ~= "AbilityType" and k ~= "TargetId" and k ~= "ActorId" then
				return false
			end
		end
		return true
	end

	local expected = if action == "Merge" or action == "BreedMutants"
		then { FirstId = true, SecondId = true }
		elseif action == "StartBattle" or action == "ReleaseMutant" then { MutantId = true }
		else nil
	if not expected then
		return false
	end
	local count = 0
	for key, value in payload do
		count += 1
		if count > 2 or not expected[key] or not validId(value) then
			return false
		end
	end
	for key in expected do
		if not validId(payload[key]) then
			return false
		end
	end
	return true
end
return RequestValidator
