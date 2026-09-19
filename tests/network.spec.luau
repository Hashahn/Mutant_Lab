local RateLimiter = require("../src/server/Domain/RateLimiter")
local limit = RateLimiter.new(3, 2)
for _ = 1, 3 do
	assert(limit:Allow(1, 0))
end
assert(not limit:Allow(1, 0), "burst exceeded")
assert(limit:Allow(2, 0), "players must be isolated")
assert(not limit:Allow(1, 0.49))
assert(limit:Allow(1, 0.5))
assert(not limit:Allow(1, -10), "clock regression must not refill")
assert(limit:Allow(1, 100))
for _ = 1, 2 do
	assert(limit:Allow(1, 100))
end
assert(not limit:Allow(1, 100), "refill capped at burst")
limit:Remove(1)
assert(limit:Allow(1, 100))
print("PASS rate limiter: burst/refill/isolation/cleanup")
