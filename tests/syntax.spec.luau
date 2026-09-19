local fs = require("@lune/fs")
local luau = require("@lune/luau")
local count = 0
local function walk(path)
	for _, name in fs.readDir(path) do
		local child = path .. "/" .. name
		if fs.isDir(child) then
			walk(child)
		elseif string.match(name, "%.luau$") then
			local ok, result = pcall(luau.compile, fs.readFile(child))
			assert(ok, child .. ": " .. tostring(result))
			count += 1
		end
	end
end
walk("src")
assert(count > 0)

-- Static check: ensure all COLORS.<Color> used in WorldController exist in its COLORS table
local worldCode = fs.readFile("src/client/Controllers/WorldController.luau")
local colorsBlock = string.match(worldCode, "local COLORS = {([^}]+)}")
assert(colorsBlock, "Could not find COLORS table in WorldController.luau")
local knownColors = {}
for key in string.gmatch(colorsBlock, "([%a%d_]+)%s*=") do
	knownColors[key] = true
end
for usedColor in string.gmatch(worldCode, "COLORS%.([%a%d_]+)") do
	assert(
		knownColors[usedColor],
		string.format("Unknown color COLORS.%s in WorldController.luau", usedColor)
	)
end

print(string.format("PASS Luau compiler: %d source files (syntax only, not engine/type validation)", count))
