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
print(string.format("PASS Luau compiler: %d source files (syntax only, not engine/type validation)", count))
