--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local root = ReplicatedStorage:WaitForChild("MutantLab")
local shared = root:WaitForChild("Shared")
local GameConfig = require(shared.Config.GameConfig)
local MutantConfig = require(shared.Config.MutantConfig)
local GameState = require(script.Parent.Domain.GameState)
local GameRules = require(script.Parent.Domain.GameRules)
local RateLimiter = require(script.Parent.Domain.RateLimiter)
local RequestValidator = require(script.Parent.Domain.RequestValidator)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local Analytics = require(script.Parent.Services.AnalyticsService)

local rules = GameRules.new(GameConfig, MutantConfig, function()
	return HttpService:GenerateGUID(false)
end)
local data = PlayerDataService.new(GameConfig, MutantConfig, GameState)
local limiter = RateLimiter.new(GameConfig.RequestBurst, GameConfig.RequestRefillPerSecond)
local sessions = {}
local joining = {}
local closing = false

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = root
local function remote(class, name)
	local object = Instance.new(class)
	object.Name = name
	object.Parent = remotes
	return object
end
local getState = remote("RemoteFunction", "GetState")
local requestAction = remote("RemoteFunction", "RequestAction")
local stateChanged = remote("RemoteEvent", "StateChanged")

-- Only the floor is shared; each client presents its own lab.
local floor = Instance.new("Part")
floor.Name = "LabFloor"
floor.Anchored = true
floor.Size = Vector3.new(100, 1, 100)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Color = Color3.fromRGB(22, 29, 40)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = workspace
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LabSpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 1, 20)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1
spawn.Parent = workspace

local function snapshot(player)
	local profile = data:Get(player)
	local session = sessions[player]
	if not profile or not session then
		return nil
	end
	return GameState.snapshot(profile, session.Battle, session.Revision, data.Mode)
end
local function response(player, ok, code)
	return { Ok = ok, Code = code, State = snapshot(player) }
end
local function publish(player, notice)
	local state = snapshot(player)
	if state and player.Parent == Players then
		stateChanged:FireClient(player, state, notice)
	end
end
local function completeBattle(player, expectedSession, expectedBattle)
	-- identity checks prevent delayed callbacks from acting on replacement sessions.
	if closing or sessions[player] ~= expectedSession or expectedSession.Battle ~= expectedBattle then
		return
	end
	local profile = data:Get(player)
	if not profile then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < expectedBattle.EndsAt then
		task.delay(expectedBattle.EndsAt - now, completeBattle, player, expectedSession, expectedBattle)
		return
	end
	local tutorialBefore = table.clone(profile.Tutorial)
	local balanceBefore = profile.BioCoins
	local ok, _, reward = rules:CompleteBattle(profile, expectedBattle, now)
	if not ok then
		return
	end
	expectedSession.Battle = false
	expectedSession.Revision += 1
	Analytics.Transition(player, tutorialBefore, profile.Tutorial)
	Analytics.Economy(player, profile.BioCoins - balanceBefore, profile.BioCoins, "BattleReward")
	publish(player, { Code = "BATTLE_COMPLETE", Reward = reward })
end
getState.OnServerInvoke = function(player)
	if not limiter:Allow(player, os.clock()) then
		return { Ok = false, Code = "RATE_LIMITED" }
	end
	if closing then
		return { Ok = false, Code = "NOT_READY" }
	end
	local state = snapshot(player)
	return { Ok = state ~= nil, Code = if state then "OK" else "NOT_READY", State = state }
end
requestAction.OnServerInvoke = function(player, action, payload)
	if not limiter:Allow(player, os.clock()) then
		return { Ok = false, Code = "RATE_LIMITED" }
	end
	if not RequestValidator.isValid(action, payload) then
		return { Ok = false, Code = "INVALID_REQUEST" }
	end
	local session = sessions[player]
	local profile = data:Get(player)
	if closing or not session or not profile then
		return { Ok = false, Code = "NOT_READY" }
	end
	local before = table.clone(profile.Tutorial)
	local balance = profile.BioCoins
	local ok, code, detail
	-- Domain operations contain no yielding APIs. All validations precede mutations.
	if action == "CreateBlob" then
		ok, code = rules:CreateBlob(profile, session.Battle)
	elseif action == "Merge" then
		ok, code = rules:Merge(profile, session.Battle, payload.FirstId, payload.SecondId)
	elseif action == "ReleaseMutant" then
		ok, code = rules:ReleaseMutant(profile, session.Battle, payload.MutantId)
	elseif action == "StartBattle" then
		ok, code, detail =
			rules:StartBattle(profile, session.Battle, payload.MutantId, workspace:GetServerTimeNow())
	end
	if ok then
		if action == "StartBattle" then
			session.Battle = detail
			task.delay(
				math.max(0, detail.EndsAt - workspace:GetServerTimeNow()),
				completeBattle,
				player,
				session,
				detail
			)
		end
		session.Revision += 1
		Analytics.Transition(player, before, profile.Tutorial)
		Analytics.Economy(player, profile.BioCoins - balance, profile.BioCoins, action)
		publish(player)
	end
	return response(player, ok, code)
end

local function added(player)
	if closing or joining[player] or sessions[player] then
		return
	end
	joining[player] = true
	local profile, code = data:Load(player)
	joining[player] = nil
	if not profile then
		if player.Parent == Players then
			player:Kick("Profile unavailable (" .. tostring(code) .. "). Please rejoin shortly.")
		end
		return
	end
	if closing or player.Parent ~= Players then
		data:Remove(player)
		return
	end
	sessions[player] = { Battle = false, Revision = 1 }
	Analytics.Joined(player)
	if not profile.Tutorial.Started then
		profile.Tutorial.Started = true
		Analytics.OnboardingStarted(player)
	end
	publish(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	limiter:Remove(player)
	data:Remove(player)
end)
data:Start()
for _, player in Players:GetPlayers() do
	task.spawn(added, player)
end
game:BindToClose(function()
	closing = true
	table.clear(sessions)
	data:Close()
end)
