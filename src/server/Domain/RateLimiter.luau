--!strict
local RateLimiter = {}
RateLimiter.__index = RateLimiter
function RateLimiter.new(capacity: number, refill: number)
	return setmetatable({ capacity = capacity, refill = refill, buckets = {} }, RateLimiter)
end
function RateLimiter:Allow(key: any, now: number): boolean
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.capacity, updated = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + math.max(0, now - bucket.updated) * self.refill)
	bucket.updated = math.max(bucket.updated, now)
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end
function RateLimiter:Remove(key: any)
	self.buckets[key] = nil
end
return RateLimiter
