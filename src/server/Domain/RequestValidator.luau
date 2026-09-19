--!strict
local RequestValidator = {}
local function validId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end
function RequestValidator.isValid(action: any, payload: any): boolean
	if type(action) ~= "string" then
		return false
	end
	if action == "CreateBlob" then
		return payload == nil
	end
	if type(payload) ~= "table" then
		return false
	end
	local expected = if action == "Merge"
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
