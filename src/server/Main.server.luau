--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local hasRunService, RunService = pcall(function()
	return game:GetService("RunService")
end)
local root = ReplicatedStorage:WaitForChild("MutantLab")
local shared = root:WaitForChild("Shared")
local GameConfig = require(shared.Config.GameConfig)
local MutantConfig = require(shared.Config.MutantConfig)
local GameState = require(script.Parent.Domain.GameState)
local GameRules = require(script.Parent.Domain.GameRules)
local RateLimiter = require(script.Parent.Domain.RateLimiter)
local RequestValidator = require(script.Parent.Domain.RequestValidator)
local ExpeditionSession = require(script.Parent.Domain.ExpeditionSession)
local BreedingService = require(shared.Domain.BreedingService)
local RestCooldownService = require(shared.Domain.RestCooldownService)
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

-- Shared server foundation floor; detailed room presentation is built per-client.
local floor = Instance.new("Part")
floor.Name = "LabFloor"
floor.Anchored = true
floor.Size = Vector3.new(160, 1, 160)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Color = Color3.fromRGB(22, 29, 40)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = workspace

local function findMutant(profile: any, mutantId: any): (number?, any?)
	if type(mutantId) ~= "string" then
		return nil, nil
	end
	for index, mutant in ipairs(profile.Mutants) do
		if mutant.Id == mutantId then
			return index, mutant
		end
	end
	return nil, nil
end

local function applySquadRest(profile: any, squad: any)
	local now = os.time()
	local ids = {}
	if squad.Active then
		for _, u in ipairs(squad.Active) do
			local cleanId = if u.Id:sub(1, 2) == "p_" then u.Id:sub(3) else u.Id
			ids[cleanId] = true
		end
	end
	if squad.Reserve then
		for _, u in ipairs(squad.Reserve) do
			local cleanId = if u.Id:sub(1, 2) == "p_" then u.Id:sub(3) else u.Id
			ids[cleanId] = true
		end
	end
	for index, m in ipairs(profile.Mutants) do
		if ids[m.Id] then
			profile.Mutants[index] = RestCooldownService.StartRest(m, now)
		end
	end
end

local function mergeSecuredLoot(profile: any, loot: any)
	if not loot then
		return
	end
	if type(profile.SecuredLoot) ~= "table" then
		profile.SecuredLoot = { BioCoins = 0, DnaFragments = 0, Items = {} }
	end
	profile.BioCoins = math.min(GameConfig.MaxBioCoins, profile.BioCoins + (loot.BioCoins or 0))
	profile.SecuredLoot.BioCoins += (loot.BioCoins or 0)
	profile.SecuredLoot.DnaFragments += (loot.DnaFragments or 0)
	if type(loot.Items) == "table" then
		for _, item in ipairs(loot.Items) do
			table.insert(profile.SecuredLoot.Items, item)
		end
	end
end

-- SecuredLoot in the expedition is a cumulative UI ledger. Only its uncredited
-- delta enters the persistent profile; all these mutations are synchronous.
local function creditExpeditionLoot(profile, expedition)
	mergeSecuredLoot(profile, expedition:TakeUncreditedLoot())
end

local function checkAndUpdateRests(profile: any, now: number)
	for index, m in ipairs(profile.Mutants) do
		if m.RestUntil and m.RestUntil <= now then
			local completed, _ = RestCooldownService.CompleteRest(m, now)
			profile.Mutants[index] = completed
		end
	end
end

local function finalizeExpedition(profile, expedition)
	if expedition.Finalized or (expedition.Status ~= "Completed" and expedition.Status ~= "Failed") then
		return
	end
	creditExpeditionLoot(profile, expedition)
	if expedition.Status == "Completed" then
		applySquadRest(profile, expedition.PlayerSquad)
	end
	expedition.Finalized = true
end

local function participantBusy(session, mutantId)
	if session.Battle and session.Battle.MutantId == mutantId then
		return true
	end
	local expedition = session.Expedition
	if
		not expedition
		or expedition.Finalized
		or expedition.Status == "Failed"
		or expedition.Status == "Completed"
	then
		return false
	end
	local groups = { expedition.PlayerSquad.Active }
	if expedition.PlayerSquad.Reserve then
		table.insert(groups, expedition.PlayerSquad.Reserve)
	end
	for _, group in ipairs(groups) do
		for _, unit in ipairs(group) do
			if unit.Id == "p_" .. mutantId or unit.Id == mutantId then
				return true
			end
		end
	end
	return false
end

local function snapshot(player)
	local profile = data:Get(player)
	local session = sessions[player]
	if not profile or not session then
		return nil
	end
	checkAndUpdateRests(profile, os.time())
	local snap = GameState.snapshot(profile, session.Battle, session.Revision, data.Mode)
	if session.Expedition and not session.Expedition.Finalized then
		snap.Expedition = session.Expedition:GetSnapshot()
		snap.Expedition.CurrentCombat = session.Expedition.CurrentCombat
	end
	return snap
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
	checkAndUpdateRests(profile, os.time())
	-- Legacy and expedition actions share the same ownership/rest locks.
	local affectedIds = {}
	if action == "Merge" or action == "BreedMutants" then
		affectedIds = { payload.FirstId, payload.SecondId }
	elseif action == "ReleaseMutant" or action == "StartBattle" then
		affectedIds = { payload.MutantId }
	elseif action == "StartExpedition" then
		for _, id in ipairs(payload.ActiveIds) do
			table.insert(affectedIds, id)
		end
		if payload.ReserveIds then
			for _, id in ipairs(payload.ReserveIds) do
				table.insert(affectedIds, id)
			end
		end
	end
	for _, id in affectedIds do
		-- Preserve the legacy duplicate-training error.
		if participantBusy(session, id) then
			return response(
				player,
				false,
				if action == "StartBattle" and session.Battle then "BATTLE_RUNNING" else "MUTANT_BUSY"
			)
		end
		local _, mutant = findMutant(profile, id)
		if mutant and RestCooldownService.IsOnRest(mutant, os.time()) then
			return response(player, false, "MUTANT_RESTING")
		end
	end
	local before = table.clone(profile.Tutorial)
	local balance = profile.BioCoins
	local ok, code, detail
	-- Domain operations contain no yielding APIs. All validations precede mutations.
	if action == "DebugSetupSquad" and hasRunService and RunService and RunService:IsStudio() then
		profile.Mutants = {
			{
				Id = "m_plasma_healer",
				Type = "PlasmaBlob",
				Tier = 3,
				Level = 1,
				Role = "Healer",
				Genes = { { Element = "Plasma", Value = 80 }, { Element = "Biomass", Value = 40 } },
			},
			{
				Id = "m_toxic_guardian",
				Type = "ToxicBlob",
				Tier = 2,
				Level = 1,
				Role = "Guardian",
				Genes = { { Element = "Toxin", Value = 60 }, { Element = "Biomass", Value = 30 } },
			},
			{
				Id = "m_blob_striker",
				Type = "Blob",
				Tier = 1,
				Level = 1,
				Role = "Striker",
				Genes = { { Element = "Biomass", Value = 25 } },
			},
		}
		profile.Tutorial = {
			Started = true,
			FreeBlobsClaimed = 2,
			FirstBlobCreated = true,
			FirstMergeCompleted = true,
			FirstBattleStarted = true,
			FirstBattleCompleted = true,
			FirstBlobPurchased = true,
			TutorialCompleted = true,
		}
		ok = true
		code = "OK"
	elseif action == "CreateBlob" then
		ok, code = rules:CreateBlob(profile, session.Battle)
	elseif action == "Merge" then
		ok, code = rules:Merge(profile, session.Battle, payload.FirstId, payload.SecondId)
	elseif action == "ReleaseMutant" then
		ok, code = rules:ReleaseMutant(profile, session.Battle, payload.MutantId)
	elseif action == "StartBattle" then
		ok, code, detail =
			rules:StartBattle(profile, session.Battle, payload.MutantId, workspace:GetServerTimeNow())
	elseif action == "StartExpedition" then
		if session.Battle then
			return response(player, false, "BATTLE_RUNNING")
		end
		if
			session.Expedition
			and session.Expedition.Status ~= "Completed"
			and session.Expedition.Status ~= "Failed"
		then
			ok = false
			code = "EXPEDITION_ACTIVE"
		else
			local mutantsById = {}
			for _, m in ipairs(profile.Mutants) do
				mutantsById[m.Id] = m
			end

			local activeUnits = {}
			local reserveUnits = {}
			local valid = true
			local now = os.time()

			for _, id in ipairs(payload.ActiveIds) do
				local m = mutantsById[id]
				if not m or (m.RestUntil and m.RestUntil > now) then
					valid = false
					break
				end
				table.insert(activeUnits, {
					Id = "p_" .. m.Id,
					Name = m.Type,
					Type = m.Type,
					Tier = m.Tier,
					Level = m.Level or 1,
					Role = m.Role or "Striker",
					Genes = m.Genes or {},
				})
			end

			if valid and payload.ReserveIds then
				for _, id in ipairs(payload.ReserveIds) do
					local m = mutantsById[id]
					if not m or (m.RestUntil and m.RestUntil > now) then
						valid = false
						break
					end
					table.insert(reserveUnits, {
						Id = "p_" .. m.Id,
						Name = m.Type,
						Type = m.Type,
						Tier = m.Tier,
						Level = m.Level or 1,
						Role = m.Role or "Striker",
						Genes = m.Genes or {},
					})
				end
			end

			if not valid or #activeUnits == 0 then
				ok = false
				code = "INVALID_SQUAD"
			else
				local expId = HttpService:GenerateGUID(false)
				session.Expedition = ExpeditionSession.new(expId, {
					Active = activeUnits,
					Reserve = reserveUnits,
				}, payload.RoomCount)
				finalizeExpedition(profile, session.Expedition)
				ok = true
				code = "OK"
			end
		end
	elseif action == "SelectCombatAction" then
		if not session.Expedition or session.Expedition.Status ~= "InCombat" then
			ok = false
			code = "NO_ACTIVE_COMBAT"
		else
			local stepOk, stepErr = session.Expedition:StepCombatAction(payload)
			ok = stepOk
			code = if stepOk then "OK" else (stepErr or "COMBAT_ACTION_FAILED")

			finalizeExpedition(profile, session.Expedition)
		end
	elseif action == "SecureLoot" then
		if not session.Expedition or session.Expedition.Status ~= "AtTerminal" then
			ok = false
			code = "NOT_AT_TERMINAL"
		else
			local secOk, secErr = session.Expedition:SecureLoot()
			ok = secOk
			code = if secOk then "OK" else (secErr or "FAILED_TO_SECURE")
			if secOk then
				creditExpeditionLoot(profile, session.Expedition)
			end
		end
	elseif action == "ProceedNextRoom" then
		if not session.Expedition or session.Expedition.Status ~= "AtTerminal" then
			ok = false
			code = "CANNOT_PROCEED"
		else
			local nextOk, nextErr = session.Expedition:ProceedToNextRoom()
			ok = nextOk
			code = if nextOk then "OK" else (nextErr or "FAILED_TO_PROCEED")

			finalizeExpedition(profile, session.Expedition)
		end
	elseif action == "Evacuate" then
		if
			not session.Expedition
			or session.Expedition.Finalized
			or session.Expedition.Status ~= "AtTerminal"
		then
			ok = false
			code = "CANNOT_EVACUATE"
		else
			local evacOk, _, evacErr = session.Expedition:Evacuate()
			if evacOk then
				finalizeExpedition(profile, session.Expedition)
				ok = true
				code = "OK"
			else
				ok = false
				code = evacErr or "CANNOT_EVACUATE"
			end
		end
	elseif action == "BreedMutants" then
		local pId = payload.FirstId or payload.PrimaryId
		local sId = payload.SecondId or payload.SecondaryId
		local primaryIndex, primary = findMutant(profile, pId)
		local secondaryIndex, secondary = findMutant(profile, sId)
		local now = os.time()
		if not primary or not secondary or primaryIndex == secondaryIndex then
			ok = false
			code = "INVALID_BREED_TARGETS"
		elseif
			(primary.RestUntil and primary.RestUntil > now)
			or (secondary.RestUntil and secondary.RestUntil > now)
		then
			ok = false
			code = "MUTANT_RESTING"
		else
			local breedOk, breedRes, breedErr = BreedingService.Breed(primary, secondary)
			if breedOk and breedRes then
				local consumedId = breedRes.ConsumedId
				local removeIndex = findMutant(profile, consumedId)
				local consumedTier = 1
				if removeIndex then
					local consumed = profile.Mutants[removeIndex]
					consumedTier = consumed.Tier
					table.remove(profile.Mutants, removeIndex)
				end
				local survivorId = breedRes.Survivor.Id
				local _, survivor = findMutant(profile, survivorId)
				if survivor then
					local oldTier = survivor.Tier
					survivor.Genes = breedRes.Survivor.Genes
					survivor.Tier = breedRes.Survivor.Tier
					survivor.Type = breedRes.Survivor.Type
					survivor.Level = breedRes.Survivor.Level

					local tierGainUnits = (2 ^ (survivor.Tier - 1)) - (2 ^ (oldTier - 1))
					local consumedUnits = 2 ^ (consumedTier - 1)
					local netConsumedDelta = math.max(0, consumedUnits - tierGainUnits)
					profile.BreedingConsumedUnits = (profile.BreedingConsumedUnits or 0) + netConsumedDelta

					if breedRes.Evolved or survivor.Tier > 1 then
						profile.Tutorial.FirstMergeCompleted = true
					end
				end
				ok = true
				code = "OK"
			else
				ok = false
				code = breedErr or "BREEDING_FAILED"
			end
		end
	end

	if ok == nil then
		ok = false
		code = "INVALID_REQUEST"
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
	local function onCharacter(character)
		task.spawn(function()
			if character.WaitForChild then
				local hrp = character:WaitForChild("HumanoidRootPart", 5)
				if hrp and hrp.IsA and hrp:IsA("BasePart") then
					hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end
			end
		end)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	if player.CharacterAdded then
		player.CharacterAdded:Connect(onCharacter)
	end
	publish(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	local profile = data:Get(player)
	local session = sessions[player]
	if profile and session and session.Expedition then
		finalizeExpedition(profile, session.Expedition)
	end
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
	for player, session in pairs(sessions) do
		local profile = data:Get(player)
		if profile and session and session.Expedition then
			finalizeExpedition(profile, session.Expedition)
		end
	end
	table.clear(sessions)
	data:Close()
end)
