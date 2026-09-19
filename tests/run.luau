local fs = require("@lune/fs")
local files = fs.readDir("tests")
table.sort(files)
local count = 0
for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		print("Running " .. file)
		require("./" .. string.gsub(file, "%.luau$", ""))
		count += 1
	end
end
assert(count > 0, "No test suites found")
print(string.format("PASS: %d suites", count))
