local validator = require("../src/server/Domain/RequestValidator")
assert(validator.isValid("CreateBlob", nil))
assert(not validator.isValid("CreateBlob", {}))
assert(validator.isValid("Merge", { FirstId = "a", SecondId = "b" }))
assert(validator.isValid("StartBattle", { MutantId = "a" }))
assert(validator.isValid("ReleaseMutant", { MutantId = "a" }))
for _, action in { "", "GrantCurrency", "CompleteBattle", 2, {} } do
	assert(not validator.isValid(action, nil), "arbitrary method rejected")
end
for _, payload in
	{
		{},
		{ MutantId = "" },
		{ MutantId = string.rep("a", 65) },
		{ MutantId = {} },
		{ MutantId = "a", Reward = 999 },
		{ MutantId = "a", UserId = 123 },
		{ MutantId = "a", [1] = "x" },
		{ MutantId = math.huge },
	}
do
	assert(not validator.isValid("StartBattle", payload))
end
assert(not validator.isValid("Merge", { FirstId = "a" }))
assert(not validator.isValid("Merge", { FirstId = "a", SecondId = false }))
-- Ownership and different-ID requirements are checked by GameRules.
print("PASS request validation: malformed arguments and extra authority fields")
