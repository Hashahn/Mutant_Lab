-- This runs the actual server entrypoint against deterministic engine/service doubles.
-- It verifies wiring and authority, not Roblox transport or DataStore availability.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local GameConfig = require("../src/shared/Config/GameConfig")
local MutantConfig = require("../src/shared/Config/MutantConfig")
local GameState = require("../src/server/Domain/GameState")
local GameRules = require("../src/server/Domain/GameRules")
local RateLimiter = require("../src/server/Domain/RateLimiter")
local RequestValidator = require("../src/server/Domain/RequestValidator")

local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			table.insert(handlers, callback)
		end,
		Fire = function(_, ...)
			for _, callback in handlers do
				callback(...)
			end
		end,
	}
end
local function node(name)
	local object = { Name = name, Children = {} }
	function object:WaitForChild(child)
		return assert(self.Children[child], child .. " missing")
	end
	function object:FireClient(player, state, notice)
		player.Messages = player.Messages or {}
		table.insert(player.Messages, { State = state, Notice = notice })
	end
	return setmetatable(object, {
		__newindex = function(self, key, value)
			rawset(self, key, value)
			if key == "Parent" and value and value.Children then
				value.Children[self.Name] = self
			end
		end,
	})
end

local now, nextId = 0, 0
local jobs = {}
local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers()
	return {}
end
local storage = node("ReplicatedStorage")
local root = node("MutantLab")
root.Parent = storage
local shared = node("Shared")
shared.Parent = root
shared.Config = { GameConfig = GameConfig, MutantConfig = MutantConfig }
local workspaceMock = node("Workspace")
function workspaceMock:GetServerTimeNow()
	return now
end
local profiles = {}
local fakeData = { Mode = "MEMORY" }
function fakeData:Load(player)
	profiles[player] = GameState.newProfile(GameConfig)
	return profiles[player], "OK"
end
function fakeData:Get(player)
	return profiles[player]
end
function fakeData:Remove(player)
	profiles[player] = nil
end
function fakeData:Start() end
function fakeData:Close()
	table.clear(profiles)
end
local analytics = {
	Joined = function() end,
	OnboardingStarted = function() end,
	Transition = function() end,
	Economy = function() end,
}
local modules = {
	Domain = {
		GameState = GameState,
		GameRules = GameRules,
		RateLimiter = RateLimiter,
		RequestValidator = RequestValidator,
	},
	Services = {
		PlayerDataService = {
			new = function()
				return fakeData
			end,
		},
		AnalyticsService = analytics,
	},
}
local services = {
	Players = Players,
	ReplicatedStorage = storage,
	HttpService = {
		GenerateGUID = function()
			nextId += 1
			return "id-" .. nextId
		end,
	},
}
local close
local gameMock = {}
function gameMock:GetService(name)
	return assert(services[name], name)
end
function gameMock:BindToClose(callback)
	close = callback
end
local function triple(...)
	return { ... }
end
local env = {
	game = gameMock,
	workspace = workspaceMock,
	script = { Parent = modules },
	require = function(module)
		return module
	end,
	Instance = {
		new = function(class)
			return node(class)
		end,
	},
	Vector3 = { new = triple },
	Color3 = { fromRGB = triple },
	Enum = { Material = { SmoothPlastic = "SmoothPlastic" } },
	os = {
		clock = function()
			return now
		end,
	},
	task = {
		spawn = function(callback, ...)
			callback(...)
		end,
		delay = function(delay, callback, ...)
			table.insert(jobs, { At = now + delay, Callback = callback, Args = { ... } })
		end,
	},
}
luau.load(
	fs.readFile("src/server/Main.server.luau"),
	{ environment = env, debugName = "Main.server integration" }
)()
local remotes = root:WaitForChild("Remotes")
local get = remotes:WaitForChild("GetState").OnServerInvoke
local request = remotes:WaitForChild("RequestAction").OnServerInvoke
local a = { UserId = 1, Parent = Players }
function a:Kick(message)
	self.Kicked = message
end
local b = { UserId = 2, Parent = Players }
function b:Kick(message)
	self.Kicked = message
end
Players.PlayerAdded:Fire(a)
Players.PlayerAdded:Fire(b)
assert(get(a).State.BioCoins == 100)
assert(request(a, "CreateBlob", nil).Ok)
assert(request(a, "CreateBlob", nil).Ok)
local first, second = profiles[a].Mutants[1].Id, profiles[a].Mutants[2].Id
assert(not request(b, "Merge", { FirstId = first, SecondId = second }).Ok, "cross-player merge")
assert(not request(a, "Merge", { FirstId = first, SecondId = first }).Ok, "duplicate ID")
assert(request(a, "Merge", { FirstId = first, SecondId = second }).Ok)
local toxic = profiles[a].Mutants[1].Id
assert(request(a, "StartBattle", { MutantId = toxic }).Ok)
assert(request(a, "StartBattle", { MutantId = toxic }).Code == "BATTLE_RUNNING")
assert(request(a, "CompleteBattle", { Reward = 999 }).Code == "INVALID_REQUEST")
assert(profiles[a].BioCoins == 100)
now = 6
local finish = jobs[1]
finish.Callback(table.unpack(finish.Args))
assert(profiles[a].BioCoins == 135 and profiles[a].Tutorial.TutorialCompleted)
finish.Callback(table.unpack(finish.Args))
assert(profiles[a].BioCoins == 135, "duplicate timer reward")
assert(profiles[b].BioCoins == 100 and #profiles[b].Mutants == 0, "other player unchanged")
assert(request(a, "CreateBlob", nil).State.BioCoins == 85)
assert(get(a).State.Battle == false)
local battleNotice = a.Messages[#a.Messages - 1]
assert(battleNotice.Notice.Code == "BATTLE_COMPLETE" and battleNotice.Notice.Reward == 35)
assert(request(a, "StartBattle", { MutantId = toxic }).Ok)
local pending = jobs[#jobs]
Players.PlayerRemoving:Fire(a)
now = 12
pending.Callback(table.unpack(pending.Args))
assert(profiles[a] == nil, "leave cancels delayed reward")
close()
assert(request(b, "CreateBlob", nil).Code == "NOT_READY")
print("PASS actual server wiring: core loop, owner isolation, one reward, leave, shutdown")
